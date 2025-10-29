locals {
  name_prefix = lower("${var.project}-${var.environment}")
}

# ---------- Resource Group ----------
resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = var.tags
}

# ---------- Monitoring ----------
resource "azurerm_log_analytics_workspace" "law" {
  name                = "log-${local.name_prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "ai" {
  name                = "appi-${local.name_prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
  tags                = var.tags
}

# ---------- App Service Plan ----------
resource "azurerm_service_plan" "plan" {
  name                = "plan-${local.name_prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Windows"
  sku_name            = "F1"
  tags                = var.tags
}

# ---------- SQL (server + db) ----------
resource "random_password" "sql_admin" {
  length  = 20
  special = true
}

resource "azurerm_mssql_server" "sql" {
  name                         = "sql-${local.name_prefix}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = random_password.sql_admin.result
  minimum_tls_version          = "1.2"
  tags                         = var.tags
}

resource "azurerm_mssql_database" "db" {
  name           = "db-${local.name_prefix}"
  server_id      = azurerm_mssql_server.sql.id
  sku_name       = "Basic" # cost-friendly; upgrade later
  zone_redundant = false
  max_size_gb    = 2
  tags           = var.tags
}

# Allow Azure services to reach SQL (quick start; we’ll remove in Phase 2)
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Build a connection string the apps can use
locals {
  sql_connection_string = "Server=tcp.${azurerm_mssql_server.sql.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.db.name};Persist Security Info=False;User ID=${var.sql_admin_login};Password=${random_password.sql_admin.result};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
}

# ---------- API App ----------
resource "azurerm_windows_web_app" "api" {
  name                = "app-${local.name_prefix}-api"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = true
  tags                = var.tags

  site_config {
    application_stack {
      current_stack = "node"
      node_version  = "~18" # e.g., NODE:18-lts
    }
    always_on = false
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.ai.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.ai.connection_string
    "SQL_CONNECTION_STRING"                 = local.sql_connection_string
    "NODE_ENV"                              = var.environment
  }
}

# ---------- Frontend App ----------
resource "azurerm_windows_web_app" "app" {
  name                = "app-${local.name_prefix}-web"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = true
  tags                = var.tags

  site_config {
    application_stack {
      current_stack = "node"
      node_version  = "~18"
    }
    always_on = false
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.ai.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.ai.connection_string
    "API_BASE_URL"                          = "https://${azurerm_windows_web_app.api.default_hostname}"
  }
}
