# Azure Serverless Monitoring & Alarm Resources

resource "azurerm_resource_group" "monitoring" {
  name     = "rg-vps-monitoring"
  location = "francecentral"
}

resource "azurerm_storage_account" "monitoring" {
  name                     = "aloisvpsmonstore"
  resource_group_name      = azurerm_resource_group.monitoring.name
  location                 = azurerm_resource_group.monitoring.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "monitoring" {
  name                = "asp-vps-monitoring"
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = azurerm_resource_group.monitoring.location
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption Plan (Serverless)
}

data "archive_file" "azure_health_check_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src/azure_health_check"
  output_path = "${path.module}/src/azure_health_check.zip"
}

resource "azurerm_storage_container" "deployments" {
  name                  = "function-releases"
  storage_account_name  = azurerm_storage_account.monitoring.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "health_check" {
  name                   = "azure_health_check-${data.archive_file.azure_health_check_zip.output_md5}.zip"
  storage_account_name   = azurerm_storage_account.monitoring.name
  storage_container_name = azurerm_storage_container.deployments.name
  type                   = "Block"
  source                 = data.archive_file.azure_health_check_zip.output_path
}

data "azurerm_storage_account_sas" "sas" {
  connection_string = azurerm_storage_account.monitoring.primary_connection_string
  https_only        = true
  start             = "2026-01-01"
  expiry            = "2036-01-01"

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
    tag     = false
    filter  = false
  }
}

resource "azurerm_linux_function_app" "health_check" {
  name                       = "alois-vps-monitoring-fn"
  resource_group_name        = azurerm_resource_group.monitoring.name
  location                   = azurerm_resource_group.monitoring.location
  storage_account_name       = azurerm_storage_account.monitoring.name
  storage_account_access_key = azurerm_storage_account.monitoring.primary_access_key
  service_plan_id            = azurerm_service_plan.monitoring.id

  site_config {
    application_stack {
      use_custom_runtime = true
    }
  }

  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE = "${azurerm_storage_blob.health_check.url}${data.azurerm_storage_account_sas.sas.sas}"
    TARGET_URL               = var.target_url == "USE_VPS_PUBLIC_IP" ? "http://${hcloud_server.vps.ipv4_address}/" : var.target_url
    TELEGRAM_TOKEN           = var.telegram_token
    TELEGRAM_CHAT_ID         = var.telegram_chat_id
    FUNCTIONS_WORKER_RUNTIME = "custom"
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"]
    ]
  }
}

# Azure Monitor Action Group pointing to the Function's /api/alertHandler endpoint
resource "azurerm_monitor_action_group" "alerts" {
  name                = "vps-monitoring-action-group"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "vps-alerts"

  webhook_receiver {
    name                    = "telegram-webhook-bridge"
    service_uri             = "https://${azurerm_linux_function_app.health_check.default_hostname}/api/alertHandler"
    use_common_alert_schema = true
  }
}

# Azure Metric Alert for HTTP 5xx errors (checking fails)
resource "azurerm_monitor_metric_alert" "vps_health_check_alert" {
  name                = "vps-health-check-alert"
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes              = [azurerm_linux_function_app.health_check.id]
  description         = "Triggers when the VPS health check fails (returns HTTP 5xx)"
  severity            = 3
  frequency           = "PT1M" # Check every 1 minute
  window_size         = "PT1M" # 1-minute window

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    operator         = "GreaterThan"
    aggregation      = "Total"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.alerts.id
  }
}
