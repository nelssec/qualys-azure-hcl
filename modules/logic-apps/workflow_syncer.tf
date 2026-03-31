locals {
  # Build ordered lists for the foreach loop in the syncer workflow
  syncer_target_locations             = var.target_locations
  syncer_regional_storage_accounts    = [for loc in var.target_locations : var.regional_storage_account_names[loc]]
  syncer_regional_artifact_containers = [for loc in var.target_locations : var.regional_artifact_container_names[loc]]
  syncer_regional_function_app_names  = [for loc in var.target_locations : var.regional_function_app_names[loc]]
}

resource "azapi_resource" "function_app_syncer" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-function-app-syncer-${var.deployment_id}"
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
          QENDPOINT = {
            defaultValue = var.qualys_endpoint
            type         = "String"
          }
          TARGET_LOCATIONS = {
            defaultValue = local.syncer_target_locations
            type         = "Array"
          }
          REGIONAL_STORAGE_ACCOUNTS = {
            defaultValue = local.syncer_regional_storage_accounts
            type         = "Array"
          }
          REGIONAL_ARTIFACT_CONTAINERS = {
            defaultValue = local.syncer_regional_artifact_containers
            type         = "Array"
          }
          REGIONAL_FUNCTION_APP_NAMES = {
            defaultValue = local.syncer_regional_function_app_names
            type         = "Array"
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
          GetVersionMapping = {
            type = "Http"
            inputs = {
              method = "GET"
              uri    = "@{concat(parameters('QENDPOINT'), '/qflow/v1/version/mapping/azure-snapshot-scanner?version=${var.app_version}')}"
              headers = {
                Authorization = "Bearer @{body('GetQualysToken')?['value']}"
              }
              retryPolicy = local.no_retry
            }
            runAfter = {
              GetQualysToken = ["Succeeded"]
            }
            limit = {
              timeout = "PT10S"
            }
          }
          GetProxyFunctionZip = {
            type = "Http"
            inputs = {
              method = "GET"
              uri    = "@{concat(parameters('QENDPOINT'), '/qflow/snapshot/v2/azure-snapshot-scanner-', body('GetVersionMapping')['version'], '-regional-functionapps.zip?format=binary&useCache=true')}"
              headers = {
                Authorization = "Bearer @{body('GetQualysToken')?['value']}"
              }
              retryPolicy = local.no_retry
            }
            runAfter = {
              GetVersionMapping = ["Succeeded"]
            }
            limit = {
              timeout = "PT180S"
            }
          }
          ForEachProxyFunctionApp = {
            type    = "Foreach"
            foreach = "@range(0, length(parameters('TARGET_LOCATIONS')))"
            actions = {
              UploadToProxyBlob = {
                type = "Http"
                inputs = {
                  method = "PUT"
                  uri    = "@{concat('https://', parameters('REGIONAL_STORAGE_ACCOUNTS')[item()], '.blob.${local.storage_suffix}/', parameters('REGIONAL_ARTIFACT_CONTAINERS')[item()], '/released-package.zip')}"
                  headers = {
                    "Content-Type"   = "application/octet-stream"
                    "x-ms-blob-type" = "BlockBlob"
                    "x-ms-date"      = "@{utcNow('R')}"
                    "x-ms-version"   = "2020-10-02"
                  }
                  body = "@body('GetProxyFunctionZip')"
                  authentication = {
                    identity = var.logic_app_identity_id
                    type     = "ManagedServiceIdentity"
                    audience = "https://storage.azure.com/"
                  }
                  retryPolicy = local.fixed_retry_3
                }
                limit = {
                  timeout = "PT3M"
                }
              }
              RestartRegionalFunctionApp = {
                type = "Http"
                inputs = {
                  method = "POST"
                  uri    = "@{concat('${local.arm_endpoint}subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Web/sites/', parameters('REGIONAL_FUNCTION_APP_NAMES')[item()], '/restart?api-version=2022-03-01')}"
                  headers = {
                    "Content-Type" = "application/json"
                  }
                  body = "POST"
                  authentication = {
                    identity = var.logic_app_identity_id
                    type     = "ManagedServiceIdentity"
                  }
                  retryPolicy = local.fixed_retry_3
                }
                limit = {
                  timeout = "PT600S"
                }
                runAfter = {
                  UploadToProxyBlob = ["Succeeded"]
                }
              }
              WaitAfterUploadRegional = {
                type = "Wait"
                inputs = {
                  interval = {
                    count = 60
                    unit  = "Second"
                  }
                }
                runAfter = {
                  RestartRegionalFunctionApp = ["Succeeded"]
                }
              }
              WaitUntilRegionalFunctionAppCreate = {
                type = "Until"
                expression = {
                  equals = [
                    "@outputs('RegionalFunctionAppHealthCheck')['statusCode']",
                    200
                  ]
                }
                limit = {
                  count   = 10
                  timeout = "PT600S"
                }
                actions = {
                  RegionalFunctionAppHealthCheck = {
                    type = "Http"
                    inputs = {
                      method = "GET"
                      uri    = "@{concat('https://', parameters('REGIONAL_FUNCTION_APP_NAMES')[item()], '.azurewebsites.net/api/health')}"
                      headers = {
                        "Content-Type" = "application/json"
                      }
                      authentication = {
                        identity = var.logic_app_identity_id
                        type     = "ManagedServiceIdentity"
                      }
                      retryPolicy = local.no_retry
                    }
                  }
                }
                runAfter = {
                  WaitAfterUploadRegional = ["Succeeded"]
                }
              }
            }
            runAfter = {
              GetProxyFunctionZip = ["Succeeded"]
            }
            runtimeConfiguration = {
              concurrency = {
                repetitions = 25
              }
            }
          }
          GetZipContent = {
            type = "Http"
            inputs = {
              method = "GET"
              uri    = "@{concat(parameters('QENDPOINT'), '/qflow/snapshot/v2/azure-snapshot-scanner-', body('GetVersionMapping')['version'], '-common-functionapps.zip?format=binary&useCache=true')}"
              headers = {
                Authorization = "Bearer @{body('GetQualysToken')?['value']}"
              }
              retryPolicy = local.no_retry
            }
            runAfter = {
              GetVersionMapping = ["Succeeded"]
            }
            limit = {
              timeout = "PT60S"
            }
          }
          UploadToBlob = {
            type = "Http"
            inputs = {
              method = "PUT"
              uri    = "https://${var.storage_account_name}.blob.${local.storage_suffix}/${var.storage_container_name}/released-package.zip"
              headers = {
                "Content-Type"   = "application/octet-stream"
                "x-ms-blob-type" = "BlockBlob"
                "x-ms-date"      = "@{utcNow('R')}"
                "x-ms-version"   = "2020-10-02"
              }
              body = "@body('GetZipContent')"
              authentication = {
                identity = var.logic_app_identity_id
                type     = "ManagedServiceIdentity"
                audience = "https://storage.azure.com/"
              }
              retryPolicy = local.fixed_retry_3
            }
            runAfter = {
              GetZipContent = ["Succeeded"]
            }
            limit = {
              timeout = "PT3M"
            }
          }
          FirstRestartFunctionApp = {
            type = "Http"
            inputs = {
              method = "POST"
              uri    = "${local.function_app_resource_id}/restart?api-version=2022-03-01"
              headers = {
                "Content-Type" = "application/json"
              }
              body = "POST"
              authentication = {
                identity = var.logic_app_identity_id
                type     = "ManagedServiceIdentity"
              }
              retryPolicy = local.fixed_retry_3
            }
            limit = {
              timeout = "PT600S"
            }
            runAfter = {
              UploadToBlob = ["Succeeded"]
            }
          }
          WaitAfterUpload = {
            type = "Wait"
            inputs = {
              interval = {
                count = 60
                unit  = "Second"
              }
            }
            runAfter = {
              FirstRestartFunctionApp = ["Succeeded"]
            }
          }
          InitializeFunctionAppHealthyFlag = {
            type = "InitializeVariable"
            inputs = {
              variables = [
                {
                  name  = "FunctionAppHealthy"
                  type  = "Boolean"
                  value = false
                }
              ]
            }
            runAfter = {
              WaitAfterUpload = ["Succeeded"]
            }
          }
          WaitUntilFunctionAppCreate = {
            type       = "Until"
            expression = "@equals(variables('FunctionAppHealthy'), bool('true'))"
            limit = {
              count   = 10
              timeout = "PT600S"
            }
            actions = {
              FunctionAppHealthCheck = {
                type = "Http"
                inputs = {
                  method = "GET"
                  uri    = "https://${local.function_app_name}.azurewebsites.net/api/health"
                  headers = {
                    "Content-Type" = "application/json"
                  }
                  authentication = {
                    identity = var.logic_app_identity_id
                    type     = "ManagedServiceIdentity"
                  }
                  retryPolicy = local.no_retry
                }
              }
              SetFunctionAppHealthyToTrue = {
                type = "SetVariable"
                inputs = {
                  name  = "FunctionAppHealthy"
                  value = "@equals(outputs('FunctionAppHealthCheck')['statusCode'], 200)"
                }
                runAfter = {
                  FunctionAppHealthCheck = ["Succeeded", "Failed", "TimedOut", "Skipped"]
                }
              }
              RestartFunctionAppIfNotHealthy = {
                type = "If"
                expression = {
                  equals = [
                    "@variables('FunctionAppHealthy')",
                    false
                  ]
                }
                actions = {
                  RestartFunctionApp = {
                    type = "Http"
                    inputs = {
                      method = "POST"
                      uri    = "${local.function_app_resource_id}/restart?api-version=2022-03-01"
                      headers = {
                        "Content-Type" = "application/json"
                      }
                      body = "POST"
                      authentication = {
                        identity = var.logic_app_identity_id
                        type     = "ManagedServiceIdentity"
                      }
                      retryPolicy = local.fixed_retry_3
                    }
                    limit = {
                      timeout = "PT600S"
                    }
                  }
                  WaitAfterRestart = {
                    type = "Wait"
                    inputs = {
                      interval = {
                        count = 60
                        unit  = "Second"
                      }
                    }
                    runAfter = {
                      RestartFunctionApp = ["Succeeded", "Failed", "TimedOut", "Skipped"]
                    }
                  }
                }
                else = {
                  actions = {}
                }
                runAfter = {
                  SetFunctionAppHealthyToTrue = ["Succeeded"]
                }
              }
            }
            runAfter = {
              InitializeFunctionAppHealthyFlag = ["Succeeded"]
            }
          }
          TriggerAppSyncer = {
            type = "Http"
            inputs = {
              method = "POST"
              uri    = "${local.arm_endpoint}subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Logic/workflows/${local.app_syncer_logic_app_name}/triggers/Recurrence/run?api-version=2019-05-01"
              headers = {
                "Content-Type" = "application/json"
              }
              body = {}
              authentication = {
                type     = "ManagedServiceIdentity"
                identity = var.logic_app_identity_id
                audience = local.arm_endpoint
              }
              retryPolicy = {
                type     = "fixed"
                count    = 3
                interval = "PT30S"
              }
            }
            runAfter = {
              WaitUntilFunctionAppCreate = ["Succeeded"]
            }
            limit = {
              timeout = "PT60S"
            }
          }
          WaitAfterAppSyncer = {
            type = "Wait"
            inputs = {
              interval = {
                count = 60
                unit  = "Second"
              }
            }
            runAfter = {
              TriggerAppSyncer = ["Succeeded"]
            }
          }
          TriggerUploadQScannerArtifacts = {
            type = "Workflow"
            inputs = {
              host = {
                workflow = {
                  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Logic/workflows/${local.workflow_prefix}-upload-qscanner-artifacts-${var.deployment_id}"
                }
                triggerName = "HttpTrigger"
              }
              headers = {
                "Content-Type" = "application/json"
              }
            }
            runAfter = {
              WaitAfterAppSyncer = ["Succeeded"]
            }
            limit = {
              timeout = "PT300S"
            }
          }
        }
      }
      parameters = local.keyvault_connection_params
    }
  }

  tags = var.tags
}

# Upload QScanner Artifacts workflow (stub with HTTP trigger, content deployed by syncer process)
resource "azapi_resource" "upload_qscanner_artifacts" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-upload-qscanner-artifacts-${var.deployment_id}"
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
        parameters     = {}
        triggers = {
          HttpTrigger = {
            type = "Request"
            kind = "Http"
            inputs = {
              schema = {}
            }
          }
        }
        actions = {
          SuccessResponse = {
            type = "Response"
            inputs = {
              statusCode = 200
              body       = { status = "ok" }
            }
            runAfter = {}
          }
        }
      }
    }
  }

  tags = var.tags
}
