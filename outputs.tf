output "resource_group" {
  value = azurerm_resource_group.rg.name
}

output "app_url" {
  value = "https://${azurerm_windows_web_app.app.default_hostname}"
}

output "api_url" {
  value = "https://${azurerm_windows_web_app.api.default_hostname}"
}

output "sql_server" {
  value = azurerm_mssql_server.sql.fully_qualified_domain_name
}

output "sql_admin_login" {
  value = var.sql_admin_login
}

# DON’T display passwords in real environments; shown here so you can test quickly
output "sql_admin_password_demo_do_not_use_in_prod" {
  value     = random_password.sql_admin.result
  sensitive = true
}
