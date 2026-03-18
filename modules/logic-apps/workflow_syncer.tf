resource "azapi_resource" "function_app_syncer" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-function-app-syncer-${var.deployment_id}"
  location  = var.location
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"

  body = {
    identity = local.identity_block
    properties = {
      state = "Enabled"
      definition = {
        "$schema"      = local.workflow_schema
        contentVersion = "1.0.0.0"
        parameters = {
          "$connections" = {
            defaultValue = {}
            type         = "Object"
          }
        }
        triggers = {
          Recurrence = {
            type = "Recurrence"
            recurrence = {
              frequency = "Hour"
              interval  = 1
            }
          }
        }
        actions = {
          GetQualysToken = {
            type = "ApiConnection"
            inputs = {
              host = {
                connection = {
                  name = "@parameters('$connections')['keyvault']['connectionId']"
                }
              }
              method = "get"
              path   = "/secrets/@{encodeURIComponent('${var.qualys_token_secret_name}')}/value"
            }
            runAfter = {}
          }
          DownloadFunctionAppZip = {
            type = "Http"
            inputs = {
              method = "GET"
              uri    = "${var.qualys_endpoint}/qflow/snapshot/v2/azure-snapshot-scanner-${var.app_version}-functionapps.zip?format=binary&useCache=true"
              headers = {
                Authorization = "Bearer @{body('GetQualysToken')?['value']}"
              }
              retryPolicy = {
                type     = "fixed"
                count    = 3
                interval = "PT30S"
              }
            }
            runAfter = {
              GetQualysToken = ["Succeeded"]
            }
            limit = {
              timeout = "PT5M"
            }
          }
          UploadToBlob = {
            type = "Http"
            inputs = {
              method = "PUT"
              uri    = "https://${var.storage_account_name}.blob.${local.storage_suffix}/${var.storage_container_name}/released-package.zip"
              headers = {
                "x-ms-blob-type" = "BlockBlob"
                "x-ms-version"   = "2020-10-02"
                "x-ms-date"      = "@{utcNow('R')}"
                "Content-Type"   = "application/octet-stream"
              }
              body = "@body('DownloadFunctionAppZip')"
              authentication = {
                type     = "ManagedServiceIdentity"
                identity = var.logic_app_identity_id
                audience = "https://storage.azure.com/"
              }
              retryPolicy = {
                type     = "fixed"
                count    = 3
                interval = "PT60S"
              }
            }
            runAfter = {
              DownloadFunctionAppZip = ["Succeeded"]
            }
            limit = {
              timeout = "PT5M"
            }
          }
        }
      }
      parameters = local.keyvault_connection_params
    }
  }

  tags = var.tags
}
