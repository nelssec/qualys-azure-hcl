output "service_vnet_id" {
  description = "ID of the service VNet"
  value       = local.service_vnet_id
}

output "service_vnet_name" {
  description = "Name of the service VNet"
  value       = local.service_vnet_name
}

output "function_app_subnet_id" {
  description = "ID of the function app subnet"
  value       = var.existing_function_app_subnet_id != null ? var.existing_function_app_subnet_id : azurerm_subnet.function_app[0].id
}

output "private_endpoint_subnet_id" {
  description = "ID of the private endpoint subnet"
  value       = var.existing_private_endpoint_subnet_id != null ? var.existing_private_endpoint_subnet_id : azurerm_subnet.private_endpoints[0].id
}

output "scanner_vnet_ids" {
  description = "Map of location to scanner VNet ID"
  value       = local.create_scanner_vnets ? { for loc, vnet in azurerm_virtual_network.scanner : loc => vnet.id } : var.existing_scanner_vnet_ids
}

output "scanner_subnet_ids" {
  description = "Map of location to scanner subnet ID"
  value       = local.create_scanner_vnets ? { for loc, subnet in azurerm_subnet.scanner : loc => subnet.id } : var.existing_scanner_subnet_ids
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
  value       = local.create_scanner_vnets ? { for loc, subnet in azurerm_subnet.regional_function_app : loc => subnet.id } : var.existing_regional_function_app_subnet_ids
}

output "regional_private_storage_subnet_ids" {
  description = "Map of location to regional private storage subnet ID"
  value       = local.create_scanner_vnets ? { for loc, subnet in azurerm_subnet.regional_private_storage : loc => subnet.id } : var.existing_regional_private_storage_subnet_ids
}
