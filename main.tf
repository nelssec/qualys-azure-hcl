data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

module "roles" {
  count  = var.create_roles ? 1 : 0
  source = "git::https://github.com/nelssec/qualys-azure-hcl.git//modules/roles?ref=main"

  deployment_id = local.deployment_id
  role_boundary = local.role_boundary
}

module "security" {
  source = "git::https://github.com/nelssec/qualys-azure-hcl.git//modules/security?ref=main"

  resource_group_name       = azurerm_resource_group.rg.name
  location                  = var.location
  deployment_id             = local.deployment_id
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  deployer_object_id        = data.azurerm_client_config.current.object_id
  qualys_subscription_token = var.qualys_subscription_token
  target_locations          = var.target_locations
  tags                      = local.common_tags
}

module "networking" {
  source = "git::https://github.com/nelssec/qualys-azure-hcl.git//modules/networking?ref=main"

  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  deployment_id       = local.deployment_id
  target_locations    = var.target_locations
  target_cloud        = var.target_cloud
  tags                = local.common_tags
}

module "storage" {
  source = "git::https://github.com/nelssec/qualys-azure-hcl.git//modules/storage?ref=main"

  resource_group_name           = azurerm_resource_group.rg.name
  location                      = var.location
  deployment_id                 = local.deployment_id
  scanner_identity_id           = module.security.scanner_identity_id
  scanner_identity_principal_id = module.security.scanner_identity_principal_id
  private_endpoint_subnet_id    = module.networking.private_endpoint_subnet_id
  blob_dns_zone_id              = module.networking.blob_dns_zone_id
  tags                          = local.common_tags
}

module "cosmos" {
  source = "git::https://github.com/nelssec/qualys-azure-hcl.git//modules/cosmos?ref=main"

  resource_group_name           = azurerm_resource_group.rg.name
  location                      = var.location
  deployment_id                 = local.deployment_id
  scanner_identity_id           = module.security.scanner_identity_id
  scanner_identity_principal_id = module.security.scanner_identity_principal_id
  private_endpoint_subnet_id    = module.networking.private_endpoint_subnet_id
  cosmos_dns_zone_id            = module.networking.cosmos_dns_zone_id
  tags                          = local.common_tags
}

module "keyvault_pe" {
  source = "git::https://github.com/nelssec/qualys-azure-hcl.git//modules/keyvault-pe?ref=main"

  resource_group_name        = azurerm_resource_group.rg.name
  location                   = var.location
  deployment_id              = local.deployment_id
  key_vault_id               = module.security.secrets_key_vault_id
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  keyvault_dns_zone_id       = module.networking.keyvault_dns_zone_id
  tags                       = local.common_tags
}

module "function_app" {
  source = "git::https://github.com/nelssec/qualys-azure-hcl.git//modules/function-app?ref=main"

  resource_group_name        = azurerm_resource_group.rg.name
  location                   = var.location
  deployment_id              = local.deployment_id
  subscription_id            = var.subscription_id
  scanner_identity_id        = module.security.scanner_identity_id
  scanner_identity_client_id = module.security.scanner_identity_client_id
  function_app_subnet_id     = module.networking.function_app_subnet_id
  storage_account_name       = module.storage.storage_account_name
  storage_account_key        = module.storage.storage_account_key
  cosmos_db_endpoint         = module.cosmos.cosmos_db_endpoint
  cosmos_db_name             = module.cosmos.cosmos_db_database_name
  key_vault_uri              = module.security.secrets_key_vault_uri
  qualys_endpoint            = var.qualys_endpoint
  debug_enabled              = var.debug_enabled
  app_version                = var.app_version
  scan_interval_hours        = var.scan_interval_hours
  poll_interval_hours        = var.poll_interval_hours
  location_concurrency       = var.location_concurrency
  scanners_per_location      = var.scanners_per_location
  tags                       = local.common_tags
}

module "logic_apps" {
  source = "git::https://github.com/nelssec/qualys-azure-hcl.git//modules/logic-apps?ref=main"

  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  deployment_id            = local.deployment_id
  subscription_id          = var.subscription_id
  tenant_id                = data.azurerm_client_config.current.tenant_id
  logic_app_identity_id    = module.security.logic_app_identity_id
  secrets_key_vault_name   = module.security.secrets_key_vault_name
  qualys_token_secret_name = module.security.qualys_token_secret_name
  qualys_endpoint          = var.qualys_endpoint
  function_app_hostname    = module.function_app.function_app_hostname
  storage_account_name     = module.storage.storage_account_name
  storage_container_name   = module.storage.storage_container_name
  event_based_discovery    = var.event_based_discovery
  app_version              = var.app_version
  poll_interval_hours      = var.poll_interval_hours
  scan_interval_hours      = var.scan_interval_hours
  location_concurrency     = var.location_concurrency
  scanners_per_location    = var.scanners_per_location
  target_cloud             = var.target_cloud
  tags                     = local.common_tags
  runtime_resource_tags    = var.runtime_resource_tags
}
