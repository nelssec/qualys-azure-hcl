locals {
  location_abbrev = {
    eastus             = "eus"
    eastus2            = "eus2"
    westus             = "wus"
    westus2            = "wus2"
    westus3            = "wus3"
    centralus          = "cus"
    northcentralus     = "ncus"
    southcentralus     = "scus"
    westcentralus      = "wcus"
    canadacentral      = "cac"
    canadaeast         = "cae"
    brazilsouth        = "brs"
    northeurope        = "neu"
    westeurope         = "weu"
    uksouth            = "uks"
    ukwest             = "ukw"
    francecentral      = "frc"
    francesouth        = "frs"
    germanywestcentral = "gwc"
    norwayeast         = "noe"
    switzerlandnorth   = "swn"
    uaenorth           = "uan"
    southafricanorth   = "san"
    australiaeast      = "aue"
    australiasoutheast = "ause"
    australiacentral   = "auc"
    eastasia           = "ea"
    southeastasia      = "sea"
    japaneast          = "jpe"
    japanwest          = "jpw"
    koreacentral       = "krc"
    koreasouth         = "krs"
    centralindia       = "inc"
    southindia         = "ins"
    westindia          = "inw"
    usgovvirginia      = "ugv"
    usgovarizona       = "uga"
    usgovtexas         = "ugt"
  }

  target_locations_set = toset(var.target_locations)
}

resource "azurerm_user_assigned_identity" "scanner" {
  name                = "qualys-snapshot-scanner-target-cmi-${var.deployment_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "logic_app" {
  name                = "qualys-snapshot-scanner-service-cmi-${var.deployment_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_key_vault" "secrets" {
  name                          = "qualyskv${var.deployment_id}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  soft_delete_retention_days    = 7
  purge_protection_enabled      = true
  public_network_access_enabled = var.deployer_ip_address != "" ? true : false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = var.deployer_ip_address != "" ? [var.deployer_ip_address] : []
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "deployer_kv_admin" {
  scope                = azurerm_key_vault.secrets.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.deployer_object_id
  principal_type       = "User"
}

resource "azurerm_role_assignment" "scanner_kv_reader" {
  scope                = azurerm_key_vault.secrets.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.scanner.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "logic_app_kv_reader" {
  scope                = azurerm_key_vault.secrets.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.logic_app.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_key_vault_secret" "qualys_token" {
  name         = "qualys-subscription-token"
  value        = var.qualys_subscription_token
  key_vault_id = azurerm_key_vault.secrets.id

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

resource "azurerm_key_vault" "disk_encryption" {
  for_each = local.target_locations_set

  name                        = "qualysdisk${local.location_abbrev[each.value]}${var.deployment_id}"
  location                    = each.value
  resource_group_name         = var.resource_group_name
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"
  enabled_for_disk_encryption = true
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = var.deployer_ip_address != "" ? [var.deployer_ip_address] : []
  }

  access_policy {
    tenant_id          = var.tenant_id
    object_id          = var.deployer_object_id
    key_permissions    = ["Get", "List", "Create", "Delete", "Update", "Import", "Backup", "Restore", "Recover", "Purge", "Encrypt", "Decrypt", "Sign", "Verify", "WrapKey", "UnwrapKey", "Release", "Rotate", "GetRotationPolicy", "SetRotationPolicy"]
    secret_permissions = ["Get", "List", "Set", "Delete", "Backup", "Restore", "Recover", "Purge"]
  }

  access_policy {
    tenant_id       = var.tenant_id
    object_id       = azurerm_user_assigned_identity.scanner.principal_id
    key_permissions = ["Get", "WrapKey", "UnwrapKey"]
  }

  tags = var.tags
}

resource "azurerm_key_vault_key" "disk_encryption" {
  for_each = local.target_locations_set

  name         = "disk-encryption-key"
  key_vault_id = azurerm_key_vault.disk_encryption[each.value].id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
}

resource "azurerm_disk_encryption_set" "per_location" {
  for_each = local.target_locations_set

  name                = "qualys-disk-encryption-${each.value}-${var.deployment_id}"
  location            = each.value
  resource_group_name = var.resource_group_name
  encryption_type     = "EncryptionAtRestWithCustomerKey"
  key_vault_key_id    = azurerm_key_vault_key.disk_encryption[each.value].id

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.scanner.id]
  }

  tags = var.tags
}
