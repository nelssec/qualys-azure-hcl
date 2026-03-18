output "scanner_identity_id" {
  description = "Resource ID of the scanner managed identity"
  value       = azurerm_user_assigned_identity.scanner.id
}

output "scanner_identity_client_id" {
  description = "Client ID of the scanner managed identity"
  value       = azurerm_user_assigned_identity.scanner.client_id
}

output "scanner_identity_principal_id" {
  description = "Principal ID of the scanner managed identity"
  value       = azurerm_user_assigned_identity.scanner.principal_id
}

output "logic_app_identity_id" {
  description = "Resource ID of the logic app managed identity"
  value       = azurerm_user_assigned_identity.logic_app.id
}

output "logic_app_identity_client_id" {
  description = "Client ID of the logic app managed identity"
  value       = azurerm_user_assigned_identity.logic_app.client_id
}

output "logic_app_identity_principal_id" {
  description = "Principal ID of the logic app managed identity"
  value       = azurerm_user_assigned_identity.logic_app.principal_id
}

output "secrets_key_vault_id" {
  description = "Resource ID of the secrets Key Vault"
  value       = azurerm_key_vault.secrets.id
}

output "secrets_key_vault_name" {
  description = "Name of the secrets Key Vault"
  value       = azurerm_key_vault.secrets.name
}

output "secrets_key_vault_uri" {
  description = "Vault URI of the secrets Key Vault"
  value       = azurerm_key_vault.secrets.vault_uri
}

output "qualys_token_secret_name" {
  description = "Name of the Qualys token secret in Key Vault"
  value       = azurerm_key_vault_secret.qualys_token.name
}

output "disk_encryption_set_ids" {
  description = "Map of location to disk encryption set ID"
  value       = { for loc, des in azurerm_disk_encryption_set.per_location : loc => des.id }
}
