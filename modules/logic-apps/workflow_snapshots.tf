resource "azapi_resource" "create_snapshots" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-create-snapshots-v2-${var.deployment_id}"
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
          HttpTrigger = {
            type = "Request"
            kind = "Http"
            inputs = {
              method = "POST"
              schema = {}
            }
            operationOptions = "SuppressWorkflowHeadersOnResponse"
            runtimeConfiguration = {
              concurrency = {
                runs = 1
              }
            }
          }
        }
        actions = {
          SuccessResponse = {
            type = "Response"
            kind = "Http"
            inputs = {
              headers = {
                "content-type" = "application/json"
              }
              statusCode = 202
              body = {
                message = "Accepted"
              }
            }
            operationOptions = "Asynchronous"
            runAfter         = {}
          }
          CreateSnapshots = {
            type       = "Until"
            expression = "@and(equals(outputs('Query')['statusCode'], 200), equals(length(body('Query').resources), 0))"
            actions = {
              Query = {
                type = "Http"
                inputs = {
                  uri = "${local.function_app_url}/api/db/query"
                  headers = {
                    "Content-Type" = "application/json"
                  }
                  body = {
                    body = {
                      query = "SELECT * FROM c WHERE c.state = 'Discovered' AND c.retry < 3 OFFSET 0 LIMIT 50"
                      incr  = true
                    }
                    container = "resource-inventory"
                  }
                  method         = "POST"
                  authentication = local.msi_auth
                  retryPolicy    = local.fixed_retry_3
                }
                runAfter = {}
              }
              ForEachVM = {
                type    = "Foreach"
                foreach = "@body('Query').resources"
                actions = {
                  CreateSnapshot = {
                    type = "Http"
                    inputs = {
                      uri = "${local.function_app_url}/api/arm/compute"
                      headers = {
                        "Content-Type" = "application/json"
                      }
                      body = {
                        resource = "snapshots"
                        method   = "beginCreateOrUpdate"
                        parameters = [
                          "qualys-snapshot-scanner",
                          "@{item()['disks'][0]['uid']}",
                          {
                            osType = "Linux"
                            sku = {
                              name = "Standard_LRS"
                            }
                            incremental = false
                            location    = "@{item()['location']}"
                            creationData = {
                              createOption     = "Copy"
                              sourceResourceId = "@{item()['disks'][0]['id']}"
                            }
                            publicNetworkAccess = "Disabled"
                            networkAccessPolicy = "DenyAll"
                            dataAccessAuthMode  = "None"
                            encryption = {
                              type                = "EncryptionAtRestWithCustomerKey"
                              diskEncryptionSetId = "/subscriptions/${var.subscription_id}/resourceGroups/qualys-snapshot-scanner/providers/Microsoft.Compute/diskEncryptionSets/qualys-encryption-set-@{item()['location']}-${var.deployment_id}"
                            }
                            tags = local.runtime_tags
                          }
                        ]
                      }
                      method         = "POST"
                      authentication = local.msi_auth
                      retryPolicy    = local.fixed_retry_3
                    }
                    runAfter = {}
                  }
                  VerifySnapshot = {
                    type       = "Until"
                    expression = "@and(equals(outputs('CheckStatus')['statusCode'], 200), equals(body('CheckStatus')['provisioningState'], 'Succeeded'))"
                    actions = {
                      Delay = {
                        type = "Wait"
                        inputs = {
                          interval = {
                            count = "@min(mul(add(iterationIndexes('VerifySnapshot'),1),10), 60)"
                            unit  = "Second"
                          }
                        }
                        runAfter = {}
                      }
                      CheckStatus = {
                        type = "Http"
                        inputs = {
                          uri = "${local.function_app_url}/api/arm/compute"
                          headers = {
                            "Content-Type" = "application/json"
                          }
                          body = {
                            resource   = "snapshots"
                            method     = "get"
                            parameters = ["qualys-snapshot-scanner", "@{item()['disks'][0]['uid']}"]
                          }
                          method         = "POST"
                          authentication = local.msi_auth
                          retryPolicy    = local.fixed_retry_3
                        }
                        runAfter = {
                          Delay = ["Succeeded"]
                        }
                      }
                    }
                    limit = {
                      count   = 25
                      timeout = "PT600S"
                    }
                    runAfter = {
                      CreateSnapshot = ["Succeeded"]
                    }
                  }
                  UpdateVMState = {
                    type = "Http"
                    inputs = {
                      uri = "${local.function_app_url}/api/db/update"
                      headers = {
                        "Content-Type" = "application/json"
                      }
                      body = {
                        body = {
                          id = "@items('ForEachVM')['id']"
                          ops = [
                            {
                              op   = "add"
                              path = "/snapshots"
                              value = [
                                {
                                  diskName   = "@{items('ForEachVM')['disks'][0]['name']}"
                                  diskSizeGB = "@body('CheckStatus')?['diskSizeGB']"
                                  encryption = "@body('CheckStatus')?['encryption']"
                                  id         = "@{body('CheckStatus')?['id']}"
                                  name       = "@{body('CheckStatus')?['name']}"
                                  uid        = "@{items('ForEachVM')['disks'][0]['uid']}"
                                }
                              ]
                            },
                            {
                              op    = "replace"
                              path  = "/state"
                              value = "@if(and(equals(outputs('CheckStatus')?['statusCode'], 200), equals(body('CheckStatus')?['provisioningState'], 'Succeeded')), 'SnapshotsCompleted', 'SnapshotsFailed')"
                            },
                            {
                              op    = "replace"
                              path  = "/retry"
                              value = 0
                            }
                          ]
                          partitionKey = "@items('ForEachVM')['location']"
                        }
                        container = "resource-inventory"
                      }
                      method         = "POST"
                      authentication = local.msi_auth
                      retryPolicy    = local.fixed_retry_3
                    }
                    runAfter = {
                      VerifySnapshot = ["Succeeded"]
                    }
                  }
                  IsSnapshotCompleted = {
                    type = "If"
                    expression = {
                      and = [
                        {
                          equals = ["@outputs('CheckStatus')?['statusCode']", 200]
                        },
                        {
                          equals = ["@body('CheckStatus')?['provisioningState']", "Succeeded"]
                        }
                      ]
                    }
                    actions = {
                      CreateInventoryScans = {
                        type = "Http"
                        inputs = {
                          uri = "${local.function_app_url}/api/scan/create"
                          headers = {
                            "Content-Type" = "application/json"
                          }
                          body = {
                            resources = "@body('Query').resources"
                          }
                          method         = "POST"
                          authentication = local.msi_auth
                          retryPolicy    = local.fixed_retry_3
                        }
                        runAfter = {}
                      }
                    }
                    runAfter = {
                      UpdateVMState = ["Succeeded"]
                    }
                  }
                }
                runtimeConfiguration = {
                  concurrency = {
                    repetitions = 50
                  }
                }
                runAfter = {
                  Query = ["Succeeded"]
                }
              }
            }
            limit = {
              count   = 5000
              timeout = "PT1440S"
            }
            runAfter = {
              SuccessResponse = ["Succeeded"]
            }
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "azapi_resource" "create_disks" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-create-disks-${var.deployment_id}"
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
          InitializeDisksArray = {
            type = "InitializeVariable"
            inputs = {
              variables = [
                {
                  name  = "Disks"
                  type  = "array"
                  value = []
                }
              ]
            }
            runAfter = {}
          }
          ForEachSnapshot = {
            type    = "Foreach"
            foreach = "@triggerBody()['snapshots']"
            actions = {
              CreateDisk = {
                type = "Http"
                inputs = {
                  uri = "${local.function_app_url}/api/arm/compute"
                  headers = {
                    "Content-Type" = "application/json"
                  }
                  body = {
                    resource = "disks"
                    method   = "beginCreateOrUpdate"
                    parameters = [
                      "qualys-snapshot-scanner",
                      "qualys-disk-@{items('ForEachSnapshot')['uid']}",
                      {
                        osType = "Linux"
                        sku = {
                          name = "StandardSSD_LRS"
                        }
                        location = "@{triggerBody()['location']}"
                        creationData = {
                          createOption     = "Copy"
                          sourceResourceId = "@{items('ForEachSnapshot')['id']}"
                        }
                        publicNetworkAccess = "Disabled"
                        networkAccessPolicy = "DenyAll"
                        dataAccessAuthMode  = "None"
                        encryption = {
                          type                = "EncryptionAtRestWithCustomerKey"
                          diskEncryptionSetId = "/subscriptions/${var.subscription_id}/resourceGroups/qualys-snapshot-scanner/providers/Microsoft.Compute/diskEncryptionSets/qualys-encryption-set-@{triggerBody()['location']}-${var.deployment_id}"
                        }
                        tags = local.runtime_tags
                      }
                    ]
                  }
                  method         = "POST"
                  authentication = local.msi_auth
                  retryPolicy    = local.fixed_retry_3
                }
                runAfter = {}
              }
              WaitUntilDiskCreated = {
                type       = "Until"
                expression = "@and(equals(outputs('CheckDiskStatus')['statusCode'], 200),equals(body('CheckDiskStatus')['provisioningState'], 'Succeeded'))"
                actions = {
                  WaitForDisk = {
                    type = "Wait"
                    inputs = {
                      interval = {
                        count = "@min(mul(add(iterationIndexes('WaitUntilDiskCreated'),1),10), 60)"
                        unit  = "Second"
                      }
                    }
                    runAfter = {}
                  }
                  CheckDiskStatus = {
                    type = "Http"
                    inputs = {
                      uri = "${local.function_app_url}/api/arm/compute"
                      headers = {
                        "Content-Type" = "application/json"
                      }
                      body = {
                        resource   = "disks"
                        method     = "get"
                        parameters = ["qualys-snapshot-scanner", "qualys-disk-@{items('ForEachSnapshot')['uid']}"]
                      }
                      method         = "POST"
                      authentication = local.msi_auth
                      retryPolicy    = local.fixed_retry_3
                    }
                    runAfter = {
                      WaitForDisk = ["Succeeded"]
                    }
                  }
                }
                limit = {
                  count   = 20
                  timeout = "PT600S"
                }
                runAfter = {
                  CreateDisk = ["Succeeded"]
                }
              }
              PushDisk = {
                type = "AppendToArrayVariable"
                inputs = {
                  name = "Disks"
                  value = {
                    disk     = "@body('CheckDiskStatus')"
                    snapshot = "@items('ForEachSnapshot')"
                  }
                }
                runAfter = {
                  WaitUntilDiskCreated = ["Succeeded"]
                }
              }
            }
            runtimeConfiguration = {
              concurrency = {
                repetitions = 10
              }
            }
            runAfter = {
              InitializeDisksArray = ["Succeeded"]
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
              body       = "@variables('Disks')"
            }
            runAfter = {
              ForEachSnapshot = ["Succeeded"]
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
                message = "@{outputs('ForEachSnapshot')}"
              }
            }
            runAfter = {
              ForEachSnapshot = ["TIMEDOUT", "FAILED"]
            }
          }
        }
      }
    }
  }

  tags = var.tags
}
