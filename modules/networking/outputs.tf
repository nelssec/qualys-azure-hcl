output "service_vnet_id" {
  description = "ID of the service VNet"
  value       = azurerm_virtual_network.service.id
}

output "service_vnet_name" {
  description = "Name of the service VNet"
  value       = azurerm_virtual_network.service.name
}

output "function_app_subnet_id" {
  description = "ID of the function app subnet"
  value       = azurerm_subnet.function_app.id
}

output "private_endpoint_subnet_id" {
  description = "ID of the private endpoint subnet"
  value       = azurerm_subnet.private_endpoints.id
}

output "scanner_vnet_ids" {
  description = "Map of location to scanner VNet ID"
  value       = { for loc, vnet in azurerm_virtual_network.scanner : loc => vnet.id }
}

output "scanner_subnet_ids" {
  description = "Map of location to scanner subnet ID"
  value       = { for loc, subnet in azurerm_subnet.scanner : loc => subnet.id }
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
