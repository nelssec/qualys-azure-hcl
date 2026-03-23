resource "azapi_resource" "delete_snapshots" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-delete-snapshots-${var.deployment_id}"
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
              method = "POST"
              schema = {}
            }
            operationOptions = "SuppressWorkflowHeadersOnResponse"
          }
        }
        actions = {
          ForEachSnapshot = {
            type    = "Foreach"
            foreach = "@triggerBody()['snapshots']"
            actions = {
              IsForceDelete = {
                type = "If"
                expression = {
                  or = [
                    {
                      equals = ["@triggerBody()?['force']", "@bool('true')"]
                    },
                    {
                      lessOrEquals = [
                        "@ticks(addHours(items('ForEachSnapshot')['timeCreated'], 6))",
                        "@ticks(utcNow())"
                      ]
                    }
                  ]
                }
                actions = {
                  DeleteSnapshot = {
                    type = "Http"
                    inputs = {
                      uri = "${local.function_app_url}/api/arm/compute"
                      headers = {
                        "Content-Type" = "application/json"
                      }
                      body = {
                        resource = "snapshots"
                        method   = "beginDelete"
                        parameters = [
                          "qualys-snapshot-scanner",
                          "@{items('ForEachSnapshot')['name']}"
                        ]
                      }
                      method         = "POST"
                      authentication = local.msi_auth
                      retryPolicy    = local.fixed_retry_3
                    }
                    runAfter = {}
                  }
                  WaitUntilSnapshotDeleted = {
                    type       = "Until"
                    expression = "@equals(outputs('CheckSnapshotStatus')['statusCode'], 404)"
                    actions = {
                      Wait = {
                        type = "Wait"
                        inputs = {
                          interval = {
                            count = 30
                            unit  = "Second"
                          }
                        }
                        runAfter = {}
                      }
                      CheckSnapshotStatus = {
                        type = "Http"
                        inputs = {
                          uri = "${local.function_app_url}/api/arm/compute"
                          headers = {
                            "Content-Type" = "application/json"
                          }
                          body = {
                            resource   = "snapshots"
                            method     = "get"
                            parameters = ["qualys-snapshot-scanner", "@{items('ForEachSnapshot')['name']}"]
                          }
                          method         = "POST"
                          authentication = local.msi_auth
                          retryPolicy    = local.no_retry
                        }
                        runAfter = {
                          Wait = ["Succeeded"]
                        }
                      }
                      SupressError = {
                        type   = "Compose"
                        inputs = ""
                        runAfter = {
                          CheckSnapshotStatus = ["TIMEDOUT", "FAILED"]
                        }
                      }
                    }
                    limit = {
                      count   = 20
                      timeout = "PT600S"
                    }
                    runAfter = {
                      DeleteSnapshot = ["Succeeded"]
                    }
                  }
                }
                runAfter = {}
              }
            }
            runtimeConfiguration = {
              concurrency = {
                repetitions = 10
              }
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
                message = "OK"
              }
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
              ForEachSnapshot = ["TIMEDOUT", "FAILED", "SKIPPED"]
            }
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "azapi_resource" "delete_disks" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-delete-disks-${var.deployment_id}"
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
              method = "POST"
              schema = {}
            }
            operationOptions = "SuppressWorkflowHeadersOnResponse"
          }
        }
        actions = {
          ForEachDisk = {
            type    = "Foreach"
            foreach = "@triggerBody()['disks']"
            actions = {
              ShouldMatchCondition = {
                type = "If"
                expression = {
                  or = [
                    {
                      equals = ["@triggerBody()?['force']", "@bool('true')"]
                    },
                    {
                      lessOrEquals = [
                        "@ticks(addHours(items('ForEachDisk')['timeCreated'], 1))",
                        "@ticks(utcNow())"
                      ]
                    }
                  ]
                }
                actions = {
                  DeleteDisk = {
                    type = "Http"
                    inputs = {
                      uri = "${local.function_app_url}/api/arm/compute"
                      headers = {
                        "Content-Type" = "application/json"
                      }
                      body = {
                        resource = "disks"
                        method   = "beginDelete"
                        parameters = [
                          "qualys-snapshot-scanner",
                          "@{items('ForEachDisk')['name']}"
                        ]
                      }
                      method         = "POST"
                      authentication = local.msi_auth
                      retryPolicy    = local.fixed_retry_3
                    }
                    runAfter = {}
                  }
                  WaitUntilDiskDeleted = {
                    type       = "Until"
                    expression = "@equals(outputs('CheckDiskStatus')['statusCode'], 404)"
                    actions = {
                      Wait = {
                        type = "Wait"
                        inputs = {
                          interval = {
                            count = 30
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
                            parameters = ["qualys-snapshot-scanner", "@{items('ForEachDisk')['name']}"]
                          }
                          method         = "POST"
                          authentication = local.msi_auth
                          retryPolicy    = local.no_retry
                        }
                        runAfter = {
                          Wait = ["Succeeded"]
                        }
                      }
                      SupressError = {
                        type   = "Compose"
                        inputs = ""
                        runAfter = {
                          CheckDiskStatus = ["TIMEDOUT", "FAILED"]
                        }
                      }
                    }
                    limit = {
                      count   = 20
                      timeout = "PT600S"
                    }
                    runAfter = {
                      DeleteDisk = ["Succeeded"]
                    }
                  }
                }
                runAfter = {}
              }
            }
            runtimeConfiguration = {
              concurrency = {
                repetitions = 50
              }
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
                message = "OK"
              }
            }
            runAfter = {
              ForEachDisk = ["Succeeded"]
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
                message = "@{outputs('ForEachDisk')}"
              }
            }
            runAfter = {
              ForEachDisk = ["TIMEDOUT", "FAILED", "SKIPPED"]
            }
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "azapi_resource" "delete_nics" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-delete-nics-${var.deployment_id}"
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
              method = "POST"
              schema = {}
            }
            operationOptions = "SuppressWorkflowHeadersOnResponse"
          }
        }
        actions = {
          ForEachNic = {
            type    = "Foreach"
            foreach = "@triggerBody()['nics']"
            actions = {
              IsVMsNIC = {
                type = "If"
                expression = {
                  and = [
                    {
                      startsWith = ["@items('ForEachNic')['name']", "qualys-nic"]
                    },
                    {
                      equals = ["@items('ForEachNic')['tags']['ManagedByApp']", "QualysSnapshotScanner"]
                    }
                  ]
                }
                actions = {
                  Delay = {
                    type = "Wait"
                    inputs = {
                      interval = {
                        count = 180
                        unit  = "Second"
                      }
                    }
                    runAfter = {}
                  }
                  DeleteNic = {
                    type = "Http"
                    inputs = {
                      uri = "${local.function_app_url}/api/arm/network"
                      headers = {
                        "Content-Type" = "application/json"
                      }
                      body = {
                        resource = "networkInterfaces"
                        method   = "beginDeleteAndWait"
                        parameters = [
                          "qualys-snapshot-scanner",
                          "@{items('ForEachNic')['name']}"
                        ]
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
                runAfter = {}
              }
            }
            runtimeConfiguration = {
              concurrency = {
                repetitions = 50
              }
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
                message = "OK"
              }
            }
            runAfter = {
              ForEachNic = ["Succeeded"]
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
                message = "@{outputs('ForEachNic')}"
              }
            }
            runAfter = {
              ForEachNic = ["TIMEDOUT", "FAILED", "SKIPPED"]
            }
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "azapi_resource" "delete_public_ips" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-delete-public-ips-${var.deployment_id}"
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
              method = "POST"
              schema = {}
            }
            operationOptions = "SuppressWorkflowHeadersOnResponse"
          }
        }
        actions = {
          ForEachPublicIp = {
            type    = "Foreach"
            foreach = "@triggerBody()['publicIps']"
            actions = {
              Delay = {
                type = "Wait"
                inputs = {
                  interval = {
                    count = 180
                    unit  = "Second"
                  }
                }
                runAfter = {}
              }
              DeletePublicIp = {
                type = "Http"
                inputs = {
                  uri = "${local.function_app_url}/api/arm/network"
                  headers = {
                    "Content-Type" = "application/json"
                  }
                  body = {
                    resource = "publicIPAddresses"
                    method   = "beginDeleteAndWait"
                    parameters = [
                      "qualys-snapshot-scanner",
                      "@{items('ForEachPublicIp')['name']}"
                    ]
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
            runtimeConfiguration = {
              concurrency = {
                repetitions = 50
              }
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
                message = "OK"
              }
            }
            runAfter = {
              ForEachPublicIp = ["Succeeded"]
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
                message = "@{outputs('ForEachPublicIp')}"
              }
            }
            runAfter = {
              ForEachPublicIp = ["TIMEDOUT", "FAILED", "SKIPPED"]
            }
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "azapi_resource" "delete_scanner_machines" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-delete-scanner-machines-${var.deployment_id}"
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
              method = "POST"
              schema = {}
            }
            operationOptions = "SuppressWorkflowHeadersOnResponse"
          }
        }
        actions = {
          ForEachScannerMachine = {
            type    = "Foreach"
            foreach = "@triggerBody()['vms']"
            actions = {
              ShouldMatchCondition = {
                type = "If"
                expression = {
                  or = [
                    {
                      equals = ["@triggerBody()?['force']", "@bool('true')"]
                    },
                    {
                      lessOrEquals = [
                        "@ticks(addHours(items('ForEachScannerMachine')['timeCreated'], 1))",
                        "@ticks(utcNow())"
                      ]
                    }
                  ]
                }
                actions = {
                  DeleteScannerMachine = {
                    type = "Http"
                    inputs = {
                      uri = "${local.function_app_url}/api/arm/compute"
                      headers = {
                        "Content-Type" = "application/json"
                      }
                      body = {
                        resource = "virtualMachines"
                        method   = "beginDelete"
                        parameters = [
                          "qualys-snapshot-scanner",
                          "@{items('ForEachScannerMachine')['name']}",
                          {
                            forceDeletion = true
                          }
                        ]
                      }
                      method         = "POST"
                      authentication = local.msi_auth
                      retryPolicy    = local.fixed_retry_3
                    }
                    runAfter = {}
                  }
                  WaitUntilScannerMachineDeleted = {
                    type       = "Until"
                    expression = "@equals(outputs('CheckScannerMachineStatus')['statusCode'], 404)"
                    actions = {
                      Wait = {
                        type = "Wait"
                        inputs = {
                          interval = {
                            count = 60
                            unit  = "Second"
                          }
                        }
                        runAfter = {}
                      }
                      CheckScannerMachineStatus = {
                        type = "Http"
                        inputs = {
                          uri = "${local.function_app_url}/api/arm/compute"
                          headers = {
                            "Content-Type" = "application/json"
                          }
                          body = {
                            resource   = "virtualMachines"
                            method     = "get"
                            parameters = ["qualys-snapshot-scanner", "@{items('ForEachScannerMachine')['name']}"]
                          }
                          method         = "POST"
                          authentication = local.msi_auth
                          retryPolicy    = local.no_retry
                        }
                        runAfter = {
                          Wait = ["Succeeded"]
                        }
                      }
                      SupressError = {
                        type   = "Compose"
                        inputs = ""
                        runAfter = {
                          CheckScannerMachineStatus = ["TIMEDOUT", "FAILED"]
                        }
                      }
                    }
                    limit = {
                      count   = 10
                      timeout = "PT600S"
                    }
                    runAfter = {
                      DeleteScannerMachine = ["Succeeded"]
                    }
                  }
                }
                runAfter = {}
              }
            }
            runtimeConfiguration = {
              concurrency = {
                repetitions = 50
              }
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
                message = "OK"
              }
            }
            runAfter = {
              ForEachScannerMachine = ["Succeeded"]
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
                message = "@{outputs('ForEachScannerMachine')}"
              }
            }
            runAfter = {
              ForEachScannerMachine = ["TIMEDOUT", "FAILED", "SKIPPED"]
            }
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "azapi_resource" "cleanup_resources" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-cleanup-resources-v2-${var.deployment_id}"
  location  = var.location
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"

  depends_on = [
    azapi_resource.delete_snapshots,
    azapi_resource.delete_scanner_machines,
    azapi_resource.delete_disks,
    azapi_resource.delete_nics,
    azapi_resource.delete_public_ips,
  ]

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
          Recurrence = {
            type = "Recurrence"
            recurrence = {
              frequency = "Minute"
              interval  = 60
            }
            runtimeConfiguration = {
              concurrency = {
                runs = 1
              }
            }
          }
        }
        actions = {
          InitializeSnapshotsNextLink = {
            type = "InitializeVariable"
            inputs = {
              variables = [
                {
                  name  = "SnapshotsNextLink"
                  type  = "string"
                  value = ""
                }
              ]
            }
            runAfter = {}
          }
          UntilSnapshotsNextLink = {
            type       = "Until"
            expression = "@equals(variables('SnapshotsNextLink'), string(''))"
            actions = {
              FetchSnapshots = {
                type = "Http"
                inputs = {
                  uri = "${local.function_app_url}/api/arm/compute"
                  headers = {
                    "Content-Type" = "application/json"
                  }
                  body = {
                    resource   = "snapshots"
                    method     = "@{if(equals(variables('SnapshotsNextLink'), string('')), '_listByResourceGroup', '_listByResourceGroupNext')}"
                    parameters = ["qualys-snapshot-scanner", "@{variables('SnapshotsNextLink')}"]
                  }
                  method         = "POST"
                  authentication = local.msi_auth
                  retryPolicy    = local.fixed_retry_3
                }
                runAfter = {}
              }
              HasSnapshots = {
                type = "If"
                expression = {
                  and = [
                    {
                      equals = ["@outputs('FetchSnapshots')['statusCode']", 200]
                    },
                    {
                      greater = ["@length(body('FetchSnapshots')?['value'])", 0]
                    }
                  ]
                }
                actions = {
                  DeleteSnapshots = {
                    type = "Workflow"
                    inputs = {
                      host = {
                        workflow = {
                          id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Logic/workflows/${local.workflow_prefix}-delete-snapshots-${var.deployment_id}"
                        }
                        triggerName = "HttpTrigger"
                      }
                      headers = {
                        "content-type" = "application/json"
                      }
                      body = {
                        snapshots = "@body('FetchSnapshots')?['value']"
                      }
                      retryPolicy = local.no_retry
                    }
                    runAfter = {}
                  }
                }
                runAfter = {
                  FetchSnapshots = ["Succeeded"]
                }
              }
              SetSnapshotsNextLink = {
                type = "SetVariable"
                inputs = {
                  name  = "SnapshotsNextLink"
                  value = "@{if(empty(body('FetchSnapshots')?['nextLink']), '', body('FetchSnapshots')?['nextLink'])}"
                }
                runAfter = {
                  HasSnapshots = ["Succeeded", "SKIPPED", "FAILED", "TIMEDOUT"]
                }
              }
            }
            limit = {
              count   = 10
              timeout = "PT600S"
            }
            runAfter = {
              InitializeSnapshotsNextLink = ["Succeeded"]
            }
          }
          InitializeScannersNextLink = {
            type = "InitializeVariable"
            inputs = {
              variables = [
                {
                  name  = "ScannersNextLink"
                  type  = "string"
                  value = ""
                }
              ]
            }
            runAfter = {}
          }
          UntilScannersNextLink = {
            type       = "Until"
            expression = "@equals(variables('ScannersNextLink'), string(''))"
            actions = {
              FetchScanners = {
                type = "Http"
                inputs = {
                  uri = "${local.function_app_url}/api/arm/compute"
                  headers = {
                    "Content-Type" = "application/json"
                  }
                  body = {
                    resource   = "virtualMachines"
                    method     = "@{if(equals(variables('ScannersNextLink'), string('')), '_list', '_listNext')}"
                    parameters = ["qualys-snapshot-scanner", "@{variables('ScannersNextLink')}"]
                  }
                  method         = "POST"
                  authentication = local.msi_auth
                  retryPolicy    = local.fixed_retry_3
                }
                runAfter = {}
              }
              HasScanners = {
                type = "If"
                expression = {
                  and = [
                    {
                      equals = ["@outputs('FetchScanners')['statusCode']", 200]
                    },
                    {
                      greater = ["@length(body('FetchScanners')?['value'])", 0]
                    }
                  ]
                }
                actions = {
                  DeleteScannerMachines = {
                    type = "Workflow"
                    inputs = {
                      host = {
                        workflow = {
                          id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Logic/workflows/${local.workflow_prefix}-delete-scanner-machines-${var.deployment_id}"
                        }
                        triggerName = "HttpTrigger"
                      }
                      headers = {
                        "content-type" = "application/json"
                      }
                      body = {
                        vms = "@body('FetchScanners')?['value']"
                      }
                      retryPolicy = local.no_retry
                    }
                    runAfter = {}
                  }
                }
                runAfter = {
                  FetchScanners = ["Succeeded"]
                }
              }
              SetScannersNextLink = {
                type = "SetVariable"
                inputs = {
                  name  = "ScannersNextLink"
                  value = "@{if(empty(body('FetchScanners')?['nextLink']), '', body('FetchScanners')?['nextLink'])}"
                }
                runAfter = {
                  HasScanners = ["Succeeded", "SKIPPED", "FAILED", "TIMEDOUT"]
                }
              }
            }
            limit = {
              count   = 10
              timeout = "PT600S"
            }
            runAfter = {
              InitializeScannersNextLink = ["Succeeded"]
            }
          }
          InitializeDisksNextLink = {
            type = "InitializeVariable"
            inputs = {
              variables = [
                {
                  name  = "DisksNextLink"
                  type  = "string"
                  value = ""
                }
              ]
            }
            runAfter = {}
          }
          UntilDisksNextLink = {
            type       = "Until"
            expression = "@equals(variables('DisksNextLink'), string(''))"
            actions = {
              FetchDisks = {
                type = "Http"
                inputs = {
                  uri = "${local.function_app_url}/api/arm/compute"
                  headers = {
                    "Content-Type" = "application/json"
                  }
                  body = {
                    resource   = "disks"
                    method     = "@{if(equals(variables('DisksNextLink'), string('')), '_listByResourceGroup', '_listByResourceGroupNext')}"
                    parameters = ["qualys-snapshot-scanner", "@{variables('DisksNextLink')}"]
                  }
                  method         = "POST"
                  authentication = local.msi_auth
                  retryPolicy    = local.fixed_retry_3
                }
                runAfter = {}
              }
              HasDisks = {
                type = "If"
                expression = {
                  and = [
                    {
                      equals = ["@outputs('FetchDisks')['statusCode']", 200]
                    },
                    {
                      greater = ["@length(body('FetchDisks')?['value'])", 0]
                    }
                  ]
                }
                actions = {
                  DeleteDisks = {
                    type = "Workflow"
                    inputs = {
                      host = {
                        workflow = {
                          id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Logic/workflows/${local.workflow_prefix}-delete-disks-${var.deployment_id}"
                        }
                        triggerName = "HttpTrigger"
                      }
                      headers = {
                        "content-type" = "application/json"
                      }
                      body = {
                        disks = "@body('FetchDisks')?['value']"
                      }
                      retryPolicy = local.no_retry
                    }
                    runAfter = {}
                  }
                }
                runAfter = {
                  FetchDisks = ["Succeeded"]
                }
              }
              SetDisksNextLink = {
                type = "SetVariable"
                inputs = {
                  name  = "DisksNextLink"
                  value = "@{if(empty(body('FetchDisks')?['nextLink']), '', body('FetchDisks')?['nextLink'])}"
                }
                runAfter = {
                  HasDisks = ["Succeeded", "SKIPPED", "FAILED", "TIMEDOUT"]
                }
              }
            }
            limit = {
              count   = 10
              timeout = "PT600S"
            }
            runAfter = {
              InitializeDisksNextLink = ["Succeeded"]
              UntilScannersNextLink   = ["Succeeded", "SKIPPED", "FAILED", "TIMEDOUT"]
            }
          }
          InitializeNicNextLink = {
            type = "InitializeVariable"
            inputs = {
              variables = [
                {
                  name  = "NicNextLink"
                  type  = "string"
                  value = ""
                }
              ]
            }
            runAfter = {}
          }
          UntilNicsNextLink = {
            type       = "Until"
            expression = "@equals(variables('NicNextLink'), string(''))"
            actions = {
              FetchNics = {
                type = "Http"
                inputs = {
                  uri = "${local.function_app_url}/api/arm/network"
                  headers = {
                    "Content-Type" = "application/json"
                  }
                  body = {
                    resource   = "networkInterfaces"
                    method     = "@{if(equals(variables('NicNextLink'), string('')), '_list', '_listNext')}"
                    parameters = ["qualys-snapshot-scanner", "@{variables('NicNextLink')}"]
                  }
                  method         = "POST"
                  authentication = local.msi_auth
                  retryPolicy    = local.fixed_retry_3
                }
                runAfter = {}
              }
              HasNics = {
                type = "If"
                expression = {
                  and = [
                    {
                      equals = ["@outputs('FetchNics')['statusCode']", 200]
                    },
                    {
                      greater = ["@length(body('FetchNics')?['value'])", 0]
                    }
                  ]
                }
                actions = {
                  DeleteNics = {
                    type = "Workflow"
                    inputs = {
                      host = {
                        workflow = {
                          id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Logic/workflows/${local.workflow_prefix}-delete-nics-${var.deployment_id}"
                        }
                        triggerName = "HttpTrigger"
                      }
                      headers = {
                        "content-type" = "application/json"
                      }
                      body = {
                        nics = "@body('FetchNics')?['value']"
                      }
                      retryPolicy = local.no_retry
                    }
                    runAfter = {}
                  }
                }
                runAfter = {
                  FetchNics = ["Succeeded"]
                }
              }
              SetNicNextLink = {
                type = "SetVariable"
                inputs = {
                  name  = "NicNextLink"
                  value = "@{if(empty(body('FetchNics')?['nextLink']), '', body('FetchNics')?['nextLink'])}"
                }
                runAfter = {
                  HasNics = ["Succeeded", "SKIPPED", "FAILED", "TIMEDOUT"]
                }
              }
            }
            limit = {
              count   = 10
              timeout = "PT600S"
            }
            runAfter = {
              InitializeNicNextLink = ["Succeeded"]
              UntilScannersNextLink = ["Succeeded", "SKIPPED", "FAILED", "TIMEDOUT"]
            }
          }
          InitializePublicIpNextLink = {
            type = "InitializeVariable"
            inputs = {
              variables = [
                {
                  name  = "PublicIpNextLink"
                  type  = "string"
                  value = ""
                }
              ]
            }
            runAfter = {}
          }
          UntilPublicIpNextLink = {
            type       = "Until"
            expression = "@equals(variables('PublicIpNextLink'), string(''))"
            actions = {
              FetchPublicIps = {
                type = "Http"
                inputs = {
                  uri = "${local.function_app_url}/api/arm/network"
                  headers = {
                    "Content-Type" = "application/json"
                  }
                  body = {
                    resource   = "publicIPAddresses"
                    method     = "@{if(equals(variables('PublicIpNextLink'), string('')), '_list', '_listNext')}"
                    parameters = ["qualys-snapshot-scanner", "@{variables('PublicIpNextLink')}"]
                  }
                  method         = "POST"
                  authentication = local.msi_auth
                  retryPolicy    = local.fixed_retry_3
                }
                runAfter = {}
              }
              HasPublicIps = {
                type = "If"
                expression = {
                  and = [
                    {
                      equals = ["@outputs('FetchPublicIps')['statusCode']", 200]
                    },
                    {
                      greater = ["@length(body('FetchPublicIps')?['value'])", 0]
                    }
                  ]
                }
                actions = {
                  DeletePublicIps = {
                    type = "Workflow"
                    inputs = {
                      host = {
                        workflow = {
                          id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Logic/workflows/${local.workflow_prefix}-delete-public-ips-${var.deployment_id}"
                        }
                        triggerName = "HttpTrigger"
                      }
                      headers = {
                        "content-type" = "application/json"
                      }
                      body = {
                        publicIps = "@body('FetchPublicIps')?['value']"
                      }
                      retryPolicy = local.no_retry
                    }
                    runAfter = {}
                  }
                }
                runAfter = {
                  FetchPublicIps = ["Succeeded"]
                }
              }
              SetPublicIpNextLink = {
                type = "SetVariable"
                inputs = {
                  name  = "PublicIpNextLink"
                  value = "@{if(empty(body('FetchPublicIps')?['nextLink']), '', body('FetchPublicIps')?['nextLink'])}"
                }
                runAfter = {
                  HasPublicIps = ["Succeeded", "SKIPPED", "FAILED", "TIMEDOUT"]
                }
              }
            }
            limit = {
              count   = 10
              timeout = "PT600S"
            }
            runAfter = {
              InitializePublicIpNextLink = ["Succeeded"]
              UntilNicsNextLink          = ["Succeeded", "SKIPPED", "FAILED", "TIMEDOUT"]
            }
          }
        }
      }
    }
  }

  tags = var.tags
}
