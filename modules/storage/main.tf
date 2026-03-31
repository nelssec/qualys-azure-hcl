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

resource "azurerm_storage_account" "main" {
  name                            = "qualysst${var.deployment_id}"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  shared_access_key_enabled       = true
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true

  identity {
    type         = "UserAssigned"
    identity_ids = [var.scanner_identity_id]
  }

  blob_properties {
    versioning_enabled = false
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "function_packages" {
  name                  = "function-app-packages"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "artifact" {
  name                  = "artifact-container"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "logs" {
  name                  = "logs-container"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "changelistdb" {
  name                  = "changelistdb-container"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "scanner_blob_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.scanner_identity_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "scanner_queue_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = var.scanner_identity_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "qualys-storage-pe-${var.deployment_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "storage-blob-connection"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.blob_dns_zone_id]
  }
}

resource "azurerm_servicebus_namespace" "main" {
  name                = "qualys-sb-${var.deployment_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_servicebus_queue" "discovery" {
  name                 = "discovery-queue"
  namespace_id         = azurerm_servicebus_namespace.main.id
  partitioning_enabled = false
  max_delivery_count   = 10
  lock_duration        = "PT5M"
  default_message_ttl  = "P1D"
}

resource "azurerm_servicebus_queue" "scanning" {
  name                 = "scanning-queue"
  namespace_id         = azurerm_servicebus_namespace.main.id
  partitioning_enabled = false
  max_delivery_count   = 10
  lock_duration        = "PT5M"
  default_message_ttl  = "P1D"
}

# Regional storage accounts (one per target location)
resource "azurerm_storage_account" "regional" {
  for_each = local.target_locations_set

  name                            = "qualys${local.location_abbrev[each.value]}${var.deployment_id}"
  location                        = each.value
  resource_group_name             = var.resource_group_name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  shared_access_key_enabled       = true
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true

  identity {
    type         = "UserAssigned"
    identity_ids = [var.scanner_identity_id]
  }

  blob_properties {
    versioning_enabled = false
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "regional_artifact" {
  for_each = local.target_locations_set

  name                  = "qualys-artifact-container"
  storage_account_id    = azurerm_storage_account.regional[each.value].id
  container_access_type = "private"
}

resource "azurerm_storage_container" "regional_logs" {
  for_each = local.target_locations_set

  name                  = "qualys-logs-container"
  storage_account_id    = azurerm_storage_account.regional[each.value].id
  container_access_type = "private"
}

resource "azurerm_storage_container" "regional_changelistdb" {
  for_each = local.target_locations_set

  name                  = "qualys-changelistdb-container"
  storage_account_id    = azurerm_storage_account.regional[each.value].id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "regional_scanner_blob_contributor" {
  for_each = local.target_locations_set

  scope                = azurerm_storage_account.regional[each.value].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.scanner_identity_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_private_endpoint" "regional_storage_blob" {
  for_each = local.target_locations_set

  name                = "qualys-regional-storage-pe-${each.value}-${var.deployment_id}"
  location            = each.value
  resource_group_name = var.resource_group_name
  subnet_id           = var.regional_private_storage_subnet_ids[each.value]
  tags                = var.tags

  private_service_connection {
    name                           = "regional-storage-blob-connection"
    private_connection_resource_id = azurerm_storage_account.regional[each.value].id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.blob_dns_zone_id]
  }
}
