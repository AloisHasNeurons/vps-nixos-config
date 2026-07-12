# AWS Serverless Monitoring Resources

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
      TARGET_URL       = var.target_url
      TELEGRAM_TOKEN   = var.telegram_token
      TELEGRAM_CHAT_ID = var.telegram_chat_id
    }
  }
}

resource "aws_cloudwatch_event_rule" "every_five_minutes" {
  name                = "vps-health-check-schedule"
  description         = "Trigger VPS health check every 5 minutes"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = aws_cloudwatch_event_rule.every_five_minutes.name
  target_id = "vps-health-check-lambda"
  arn       = aws_lambda_function.health_check.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.health_check.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_five_minutes.arn
}
