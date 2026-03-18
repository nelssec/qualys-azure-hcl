resource "azapi_resource" "register_service_account" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-register-service-account-${var.deployment_id}"
  location  = var.location
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.logic_app_identity_id]
  }

  body = {
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
          HttpTrigger = {
            type = "Request"
            kind = "Http"
            inputs = {
              method = "POST"
              schema = {}
            }
            operationOptions     = "SuppressWorkflowHeadersOnResponse"
            runtimeConfiguration = {}
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
          RegisterServiceAccountApi = {
            type = "Http"
            limit = {
              timeout = "PT10S"
            }
            inputs = {
              uri = "${var.qualys_endpoint}/conn/snapshot/v1.0/register-service-account/azure"
              headers = {
                Authorization = "@{concat('Bearer ', body('GetQualysToken')?['value'])}"
              }
              method = "POST"
              body = {
                accountId = var.subscription_id
                schedule  = "0 * * ? * * *"
                tags = [
                  {
                    tagKey   = "QUALYS_SNAPSHOT_ENABLED"
                    tagValue = "true"
                  }
                ]
              }
              retryPolicy = local.no_retry
            }
            runAfter = {
              GetQualysToken = ["Succeeded"]
            }
          }
          SuccessResponse = {
            type = "Response"
            kind = "Http"
            inputs = {
              headers = {
                "content-type" = "application/json"
              }
              statusCode = 200
              body = {
                message = "@outputs('RegisterServiceAccountApi')"
              }
            }
            runAfter = {
              RegisterServiceAccountApi = ["Succeeded"]
            }
          }
          ErrorResponse = {
            type = "Response"
            kind = "Http"
            inputs = {
              headers = {
                "content-type" = "application/json"
              }
              statusCode = "@if(equals(outputs('RegisterServiceAccountApi')['statusCode'], 304), 200, outputs('RegisterServiceAccountApi')['statusCode'])"
              body = {
                message = "@outputs('RegisterServiceAccountApi')"
              }
            }
            runAfter = {
              RegisterServiceAccountApi = ["TIMEDOUT", "FAILED", "SKIPPED"]
            }
          }
        }
      }
      parameters = local.keyvault_connection_params
    }
  }

  tags = var.tags
}

resource "azapi_resource" "deregister_service_account" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-deregister-service-account-${var.deployment_id}"
  location  = var.location
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.logic_app_identity_id]
  }

  body = {
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
          HttpTrigger = {
            type = "Request"
            kind = "Http"
            inputs = {
              method = "POST"
              schema = {}
            }
            operationOptions     = "SuppressWorkflowHeadersOnResponse"
            runtimeConfiguration = {}
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
          DeRegisterServiceAccountApi = {
            type = "Http"
            limit = {
              timeout = "PT10S"
            }
            inputs = {
              uri = "${var.qualys_endpoint}/conn/snapshot/v1.0/deregister-service-account/azure/${var.tenant_id}"
              headers = {
                Authorization = "@{concat('Bearer ', body('GetQualysToken')?['value'])}"
              }
              method      = "DELETE"
              retryPolicy = local.no_retry
            }
            runAfter = {
              GetQualysToken = ["Succeeded"]
            }
          }
          DisableRegisterServiceAccount = {
            type = "Http"
            inputs = {
              uri = "${local.function_app_url}/api/arm/logic"
              headers = {
                "Content-Type" = "application/json"
              }
              body = {
                resource   = "workflows"
                method     = "disable"
                parameters = ["qualys-snapshot-scanner", "qualys-register-service-account-${var.deployment_id}"]
              }
              method         = "POST"
              authentication = local.msi_auth
              retryPolicy    = local.fixed_retry_3
            }
            runAfter = {
              DeRegisterServiceAccountApi = ["Succeeded"]
            }
          }
          SuccessResponse = {
            type = "Response"
            kind = "Http"
            inputs = {
              headers = {
                "content-type" = "application/json"
              }
              statusCode = 200
              body = {
                message = {
                  DeRegisterServiceAccountApi   = "@outputs('DeRegisterServiceAccountApi')"
                  DisableRegisterServiceAccount = "@outputs('DisableRegisterServiceAccount')"
                }
              }
            }
            runAfter = {
              DisableRegisterServiceAccount = ["Succeeded"]
            }
          }
          ErrorResponse = {
            type = "Response"
            kind = "Http"
            inputs = {
              headers = {
                "content-type" = "application/json"
              }
              statusCode = 422
              body = {
                message = {
                  DeRegisterServiceAccountApi   = "@outputs('DeRegisterServiceAccountApi')"
                  DisableRegisterServiceAccount = "@outputs('DisableRegisterServiceAccount')"
                }
              }
            }
            runAfter = {
              DisableRegisterServiceAccount = ["TIMEDOUT", "FAILED", "SKIPPED"]
            }
          }
        }
      }
      parameters = local.keyvault_connection_params
    }
  }

  tags = var.tags
}
