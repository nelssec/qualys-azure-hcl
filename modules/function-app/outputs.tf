output "function_app_id" {
  description = "ID of the Function App"
  value       = azurerm_linux_function_app.main.id
}

output "function_app_name" {
  description = "Name of the Function App"
  value       = azurerm_linux_function_app.main.name
}

output "function_app_hostname" {
  description = "Default hostname of the Function App"
  value       = azurerm_linux_function_app.main.default_hostname
}

output "app_insights_connection_string" {
  description = "Application Insights connection string (empty if debug disabled)"
  value       = var.debug_enabled ? azurerm_application_insights.main[0].connection_string : ""
}
