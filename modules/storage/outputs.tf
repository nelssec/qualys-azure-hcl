output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the storage account"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "storage_account_key" {
  description = "Primary access key of the storage account"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "storage_container_name" {
  description = "Name of the function app packages container"
  value       = azurerm_storage_container.function_packages.name
}

output "service_bus_namespace" {
  description = "Name of the Service Bus namespace"
  value       = azurerm_servicebus_namespace.main.name
}

output "service_bus_namespace_id" {
  description = "ID of the Service Bus namespace"
  value       = azurerm_servicebus_namespace.main.id
}

output "service_bus_connection_string" {
  description = "Primary connection string for the Service Bus namespace"
  value       = azurerm_servicebus_namespace.main.default_primary_connection_string
  sensitive   = true
}

output "regional_storage_account_names" {
  description = "Map of location to regional storage account name"
  value       = { for loc, sa in azurerm_storage_account.regional : loc => sa.name }
}

output "regional_storage_account_ids" {
  description = "Map of location to regional storage account ID"
  value       = { for loc, sa in azurerm_storage_account.regional : loc => sa.id }
}

output "regional_artifact_container_names" {
  description = "Map of location to regional artifact container name"
  value       = { for loc, c in azurerm_storage_container.regional_artifact : loc => c.name }
}
