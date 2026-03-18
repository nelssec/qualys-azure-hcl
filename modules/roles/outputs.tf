output "function_app_role_id" {
  description = "ID of the Function App custom RBAC role"
  value       = azurerm_role_definition.function_app_role.role_definition_resource_id
}

output "logic_app_role_id" {
  description = "ID of the Logic App custom RBAC role"
  value       = azurerm_role_definition.logic_app_role.role_definition_resource_id
}

output "target_scanner_role_id" {
  description = "ID of the Target Scanner custom RBAC role"
  value       = azurerm_role_definition.target_scanner_role.role_definition_resource_id
}
