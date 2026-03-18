resource "azapi_resource" "find_scan_candidates" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-find-scan-candidates-${var.deployment_id}"
  location  = var.location
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"

  depends_on = [azapi_resource.concurrent_scanner]

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
          QENDPOINT = {
            type         = "SecureString"
            defaultValue = var.qualys_endpoint
          }
        }
        triggers = {
          Poll = {
            type = "Recurrence"
            recurrence = {
              frequency = "Minute"
              interval  = var.scan_interval_hours * 60
            }
            runtimeConfiguration = {
              concurrency = {
                runs = 1
              }
            }
          }
        }
        actions = {
          GetQualysTokenFromKV = {
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
          GetLocations = {
            type = "Http"
            inputs = {
              uri = "${local.function_app_url}/api/db/query"
              headers = {
                "Content-Type" = "application/json"
              }
              body = {
                container = "resource-inventory"
                body = {
                  query = "SELECT VALUE c.location FROM c WHERE c.state = \"SnapshotsCompleted\" AND c.retry < 3 GROUP BY c.location"
                }
              }
              method         = "POST"
              authentication = local.msi_auth
              retryPolicy    = local.fixed_retry_3
            }
            runAfter = {
              GetQualysTokenFromKV = ["Succeeded"]
            }
          }
          LogGetLocationsQueryFailed = {
            type = "Scope"
            actions = {
              QueryFailedEventLog = {
                type = "Http"
                inputs = {
                  uri = "${local.function_app_url}/api/db/create"
                  headers = {
                    "Content-Type" = "application/json"
                  }
                  body = {
                    container = "event-logs"
                    body = {
                      item = {
                        parentId       = "@{workflow()['run']['name']}"
                        triggerId      = "@{workflow()['run']['name']}"
                        runId          = "@{workflow()['run']['name']}"
                        resource       = "CosmosDb"
                        location       = var.location
                        subscriptionId = var.subscription_id
                        state          = "GetReadyToScanLocations"
                        input          = {}
                        output = {
                          GetLocations = "@outputs('GetLocations')"
                        }
                        error = true
                      }
                    }
                  }
                  method         = "POST"
                  authentication = local.msi_auth
                  retryPolicy    = local.no_retry
                }
                runAfter = {}
              }
              QueryFailedEventLogSuppressError = {
                type   = "Compose"
                inputs = ""
                runAfter = {
                  QueryFailedEventLog = ["TIMEDOUT", "FAILED"]
                }
              }
            }
            runAfter = {
              GetLocations = ["TIMEDOUT", "FAILED"]
            }
          }
          CheckQflowHealth = {
            type = "Http"
            limit = {
              timeout = "PT10S"
            }
            inputs = {
              uri = "${var.qualys_endpoint}/qflow/api/v1/health"
              headers = {
                Authorization = "@{concat('Bearer ', body('GetQualysTokenFromKV')?['value'])}"
              }
              method      = "GET"
              retryPolicy = local.no_retry
            }
            runAfter = {
              GetLocations = ["Succeeded"]
            }
          }
          ForEachLocation = {
            type    = "Foreach"
            foreach = "@body('GetLocations').resources"
            actions = {
              ConcurrentScan = {
                type = "Workflow"
                inputs = {
                  host = {
                    workflow = {
                      id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Logic/workflows/${local.workflow_prefix}-concurrent-scanner-${var.deployment_id}"
                    }
                    triggerName = "HttpTrigger"
                  }
                  headers = {
                    "content-type" = "application/json"
                  }
                  body = {
                    location = "@item()"
                  }
                  retryPolicy = local.no_retry
                }
                limit = {
                  timeout = "PT14400S"
                }
                runAfter = {}
              }
            }
            runtimeConfiguration = {
              concurrency = {
                repetitions = var.location_concurrency
              }
            }
            runAfter = {
              CheckQflowHealth = ["Succeeded"]
            }
          }
        }
      }
      parameters = local.keyvault_connection_params
    }
  }

  tags = var.tags
}

resource "azapi_resource" "concurrent_scanner" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-concurrent-scanner-${var.deployment_id}"
  location  = var.location
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"

  depends_on = [azapi_resource.prepare_scanner]

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
          QueryUntilLastDocument = {
            type       = "Until"
            expression = "@equals(outputs('HasPendingMachines'), bool('false'))"
            actions = {
              Query = {
                type = "Http"
                inputs = {
                  uri = "${local.function_app_url}/api/db/query"
                  headers = {
                    "Content-Type" = "application/json"
                  }
                  body = {
                    container = "resource-inventory"
                    body = {
                      query        = "SELECT c.subscriptionId, c.location, c.resourceGroup, c.resourceId, c.id, c.userId, c.name, c.osType, c.scanTypes, c._ts, c.ttl, c.privateIpAddress, c.privateIpv6Address, c.host, c.arch, c.retry, c.snapshots, c.discoveryTaskId, c.type FROM c WHERE c.state = \"SnapshotsCompleted\" AND c.retry < 3 OFFSET 0 LIMIT @{mul(int('${var.scanners_per_location}'), int('${var.location_concurrency}'))}"
                      partitionKey = "@{triggerBody()['location']}"
                      incr         = true
                    }
                  }
                  method         = "POST"
                  authentication = local.msi_auth
                  retryPolicy    = local.fixed_retry_3
                }
                runAfter = {}
              }
              HasPendingMachines = {
                type   = "Compose"
                inputs = "@and(equals(outputs('Query')['statusCode'], 200),not(equals(length(body('Query').resources), 0)))"
                runAfter = {
                  Query = ["Succeeded", "TIMEDOUT", "FAILED"]
                }
              }
              Condition = {
                type = "If"
                expression = {
                  and = [
                    {
                      equals = ["@outputs('HasPendingMachines')", "@bool('true')"]
                    }
                  ]
                }
                actions = {
                  PrepareBatches = {
                    type = "Http"
                    inputs = {
                      uri = "${local.function_app_url}/api/format/split-array"
                      headers = {
                        "Content-Type" = "application/json"
                      }
                      body = {
                        array = "@body('Query').resources"
                        size  = var.scanners_per_location
                      }
                      method         = "POST"
                      authentication = local.msi_auth
                      retryPolicy    = local.fixed_retry_3
                    }
                    runAfter = {}
                  }
                  ForEachBatch = {
                    type    = "Foreach"
                    foreach = "@body('PrepareBatches')"
                    actions = {
                      ExecuteScan = {
                        type = "Workflow"
                        inputs = {
                          host = {
                            workflow = {
                              id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Logic/workflows/${local.workflow_prefix}-prepare-scanner-machine-${var.deployment_id}"
                            }
                            triggerName = "HttpTrigger"
                          }
                          headers = {
                            "content-type" = "application/json"
                          }
                          body = {
                            location  = "@triggerBody()['location']"
                            instances = "@items('ForEachBatch')"
                          }
                          retryPolicy = local.no_retry
                        }
                        limit = {
                          timeout = "PT1800S"
                        }
                        runAfter = {}
                      }
                      SuppressError = {
                        type   = "Compose"
                        inputs = ""
                        runAfter = {
                          ExecuteScan = ["TIMEDOUT", "FAILED"]
                        }
                      }
                    }
                    runtimeConfiguration = {
                      concurrency = {
                        repetitions = var.location_concurrency
                      }
                    }
                    runAfter = {
                      PrepareBatches = ["Succeeded"]
                    }
                  }
                }
                runAfter = {
                  HasPendingMachines = ["Succeeded"]
                }
              }
            }
            limit = {
              count   = 1000
              timeout = "PT14400S"
            }
            runAfter = {}
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
                message = "@{outputs('QueryUntilLastDocument')}"
              }
            }
            runAfter = {
              QueryUntilLastDocument = ["Succeeded"]
            }
          }
          ErrorResponse = {
            type = "Response"
            kind = "Http"
            inputs = {
              headers = {
                "content-type" = "application/json"
              }
              statusCode = 200
              body = {
                message = "@{outputs('QueryUntilLastDocument')}"
              }
            }
            runAfter = {
              QueryUntilLastDocument = ["TIMEDOUT", "FAILED", "SKIPPED"]
            }
          }
        }
      }
    }
  }

  tags = var.tags
}
