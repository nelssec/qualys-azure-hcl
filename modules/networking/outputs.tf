output "service_vnet_id" {
  description = "ID of the service VNet"
  value       = var.service_vnet_id
}

output "function_app_subnet_id" {
  description = "ID of the function app subnet"
  value       = var.function_app_subnet_id
}

output "private_endpoint_subnet_id" {
  description = "ID of the private endpoint subnet"
  value       = var.private_endpoint_subnet_id
}

output "scanner_subnet_ids" {
  description = "Map of location to scanner subnet ID"
  value       = var.scanner_subnet_ids
}

output "keyvault_dns_zone_id" {
  description = "ID of the Key Vault private DNS zone"
  value       = azurerm_private_dns_zone.keyvault.id
}

output "blob_dns_zone_id" {
  description = "ID of the blob private DNS zone"
  value       = azurerm_private_dns_zone.blob.id
}

output "cosmos_dns_zone_id" {
  description = "ID of the Cosmos DB private DNS zone"
  value       = azurerm_private_dns_zone.cosmos.id
}

output "servicebus_dns_zone_id" {
  description = "ID of the Service Bus private DNS zone"
  value       = azurerm_private_dns_zone.servicebus.id
}

output "regional_function_app_subnet_ids" {
  description = "Map of location to regional proxy function app subnet ID"
  value       = var.regional_function_app_subnet_ids
}

output "regional_private_storage_subnet_ids" {
  description = "Map of location to regional private storage subnet ID"
  value       = var.regional_private_storage_subnet_ids
}
