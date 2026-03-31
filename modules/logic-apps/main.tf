locals {
  workflow_prefix = "qualys"

  runtime_tags = merge({
    App          = "qualys-snapshot-scanner"
    Name         = "Qualys Snapshot Scanner"
    ManagedByApp = "QualysSnapshotScanner"
    AppVersion   = var.app_version
  }, var.runtime_resource_tags)
  function_app_url = "https://${var.function_app_hostname}"

  storage_suffixes = {
    AzureCloud        = "core.windows.net"
    AzureUSGovernment = "core.usgovcloudapi.net"
    AzureChinaCloud   = "core.chinacloudapi.cn"
  }
  storage_suffix = local.storage_suffixes[var.target_cloud]

  scanner_identity_resource_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/qualys-snapshot-scanner-service-cmi-${var.deployment_id}"

  workflow_schema = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"

  keyvault_connection_host = {
    connection = {
      name = "@parameters('$connections')['keyvault']['connectionId']"
    }
  }

  keyvault_connection_params = {
    "$connections" = {
      value = {
        keyvault = {
          connectionId   = azapi_resource.keyvault_connection.id
          connectionName = azapi_resource.keyvault_connection.name
          connectionProperties = {
            authentication = {
              type     = "ManagedServiceIdentity"
              identity = var.logic_app_identity_id
            }
          }
          id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Web/locations/${var.location}/managedApis/keyvault"
        }
      }
    }
  }

  msi_auth = {
    identity = local.scanner_identity_resource_id
    type     = "ManagedServiceIdentity"
  }

  fixed_retry_3 = {
    count    = 3
    interval = "PT60S"
    type     = "fixed"
  }

  no_retry = {
    type = "none"
  }

  arm_endpoint = "https://management.azure.com/"

  function_app_name        = "qualys-snapshot-scanner-v3-${var.deployment_id}"
  function_app_resource_id = "${local.arm_endpoint}subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Web/sites/${local.function_app_name}"

  # For regional proxy function app operations
  proxy_function_app_resource_id_prefix = "${local.arm_endpoint}subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Web/sites/qualys-proxy-"

  location_abbreviations = var.target_locations

  app_syncer_logic_app_name = "${local.workflow_prefix}-app-syncer-${var.deployment_id}"
}

data "azurerm_managed_api" "keyvault" {
  name     = "keyvault"
  location = var.location
}

resource "azapi_resource" "keyvault_connection" {
  type                      = "Microsoft.Web/connections@2016-06-01"
  name                      = "keyvault-${var.deployment_id}"
  location                  = var.location
  parent_id                 = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"
  schema_validation_enabled = false

  body = {
    properties = {
      displayName        = "Key Vault Connection"
      parameterValueType = "Alternative"
      alternativeParameterValues = {
        vaultName = var.secrets_key_vault_name
      }
      api = {
        id = data.azurerm_managed_api.keyvault.id
      }
    }
  }

  tags = var.tags
}
