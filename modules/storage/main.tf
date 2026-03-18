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
