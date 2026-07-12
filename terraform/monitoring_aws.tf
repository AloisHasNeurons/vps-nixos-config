# AWS Serverless Monitoring & Alarm Resources

# 1. Health check function data source & resource
data "archive_file" "aws_health_check_zip" {
  type        = "zip"
  source_file = "${path.module}/src/aws_health_check/bootstrap"
  output_path = "${path.module}/src/aws_health_check/bootstrap.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "vps-monitoring-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "health_check" {
  filename         = data.archive_file.aws_health_check_zip.output_path
  source_code_hash = data.archive_file.aws_health_check_zip.output_base64sha256
  function_name    = "vps-health-check"
  role             = aws_iam_role.lambda_role.arn
  handler          = "bootstrap" # Ignored for provided runtime but required by schema
  runtime          = "provided.al2023"
  timeout          = 15

  environment {
    variables = {
      TARGET_URL = var.target_url == "USE_VPS_PUBLIC_IP" ? "http://${hcloud_server.vps.ipv4_address}/" : var.target_url
    }
  }
}

# 2. EventBridge Scheduler (every 1 minute)
resource "aws_cloudwatch_event_rule" "every_one_minute" {
  name                = "vps-health-check-schedule-1min"
  description         = "Trigger VPS health check every 1 minute"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = aws_cloudwatch_event_rule.every_one_minute.name
  target_id = "vps-health-check-lambda"
  arn       = aws_lambda_function.health_check.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.health_check.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_one_minute.arn
}

# 3. Telegram Notifier function (triggered by SNS alerts)
data "archive_file" "aws_telegram_notifier_zip" {
  type        = "zip"
  source_file = "${path.module}/src/telegram_notifier/bootstrap"
  output_path = "${path.module}/src/telegram_notifier/bootstrap.zip"
}

resource "aws_lambda_function" "telegram_notifier" {
  filename         = data.archive_file.aws_telegram_notifier_zip.output_path
  source_code_hash = data.archive_file.aws_telegram_notifier_zip.output_base64sha256
  function_name    = "vps-telegram-notifier"
  role             = aws_iam_role.lambda_role.arn
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  timeout          = 15

  environment {
    variables = {
      TARGET_URL       = var.target_url == "USE_VPS_PUBLIC_IP" ? "http://${hcloud_server.vps.ipv4_address}/" : var.target_url
      TELEGRAM_TOKEN   = var.telegram_token
      TELEGRAM_CHAT_ID = var.telegram_chat_id
    }
  }
}

# 4. SNS Topic for Alarm Transitions
resource "aws_sns_topic" "alerts" {
  name = "vps-health-check-alerts-topic"
}

resource "aws_sns_topic_subscription" "notifier_subscription" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.telegram_notifier.arn
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.telegram_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

# 5. CloudWatch Metric Alarm
resource "aws_cloudwatch_metric_alarm" "vps_health_check_alarm" {
  alarm_name          = "vps-health-check-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60 # 1 minute
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Triggers when the VPS health check fails"
  treat_missing_data  = "breaching"

  dimensions = {
    FunctionName = aws_lambda_function.health_check.function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
