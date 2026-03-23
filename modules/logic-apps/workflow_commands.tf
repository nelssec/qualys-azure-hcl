resource "azapi_resource" "run_commands" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-run-commands-${var.deployment_id}"
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
          QENDPOINT = {
            type         = "SecureString"
            defaultValue = var.qualys_endpoint
          }
          SUBSCRIPTION_ID = {
            type         = "SecureString"
            defaultValue = var.subscription_id
          }
          RESOURCE_GROUP_NAME = {
            type         = "SecureString"
            defaultValue = "qualys-snapshot-scanner"
          }
          BUILD_VERSION = {
            type         = "SecureString"
            defaultValue = var.app_version
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
          SuccessResponse = {
            type = "Response"
            kind = "Http"
            inputs = {
              headers = {
                "content-type" = "application/json"
              }
              statusCode = 200
              body = {
                message = "RunCommands workflow triggered"
              }
            }
            runAfter = {}
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "azapi_resource" "prepare_scanner" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-prepare-scanner-machine-${var.deployment_id}"
  location  = var.location
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"

  depends_on = [
    azapi_resource.run_commands,
    azapi_resource.create_disks,
    azapi_resource.delete_snapshots,
    azapi_resource.delete_scanner_machines,
  ]

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
          SUBSCRIPTION_ID = {
            type         = "SecureString"
            defaultValue = var.subscription_id
          }
          RESOURCE_GROUP_NAME = {
            type         = "SecureString"
            defaultValue = "qualys-snapshot-scanner"
          }
          BUILD_VERSION = {
            type         = "SecureString"
            defaultValue = var.app_version
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
          InitializeId = {
            type = "InitializeVariable"
            inputs = {
              variables = [
                {
                  name  = "Id"
                  type  = "string"
                  value = "@{workflow()['run']['name']}"
                }
              ]
            }
            runAfter = {}
          }
          InitializeVMIdsArray = {
            type = "InitializeVariable"
            inputs = {
              variables = [
                {
                  name  = "VMIds"
                  type  = "array"
                  value = []
                }
              ]
            }
            runAfter = {
              InitializeId = ["Succeeded"]
            }
          }
          InitializeInstanceAndDisksArray = {
            type = "InitializeVariable"
            inputs = {
              variables = [
                {
                  name  = "InstanceAndDisks"
                  type  = "array"
                  value = []
                }
              ]
            }
            runAfter = {
              InitializeVMIdsArray = ["Succeeded"]
            }
          }
          ForEachInstanceCreateDisks = {
            type    = "Foreach"
            foreach = "@triggerBody()['instances']"
            actions = {
              AddVMId = {
                type = "AppendToArrayVariable"
                inputs = {
                  name  = "VMIds"
                  value = "@{item()['id']}"
                }
                runAfter = {}
              }
              CreateDisks = {
                type = "Workflow"
                inputs = {
                  host = {
                    workflow = {
                      id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Logic/workflows/${local.workflow_prefix}-create-disks-${var.deployment_id}"
                    }
                    triggerName = "HttpTrigger"
                  }
                  headers = {
                    "content-type" = "application/json"
                  }
                  body = {
                    parentId       = "@variables('Id')"
                    vmId           = "@{item()['id']}"
                    subscriptionId = "@{item()['subscriptionId']}"
                    location       = "@{triggerBody()['location']}"
                    snapshots      = "@item()['snapshots']"
                  }
                  retryPolicy = {
                    count    = 2
                    interval = "PT60S"
                    type     = "fixed"
                  }
                }
                limit = {
                  timeout = "PT180S"
                }
                runAfter = {
                  AddVMId = ["Succeeded"]
                }
              }
              SetInstanceAndDisks = {
                type = "AppendToArrayVariable"
                inputs = {
                  name = "InstanceAndDisks"
                  value = {
                    instance = "@item()"
                    disks    = "@body('CreateDisks')"
                  }
                }
                runAfter = {
                  CreateDisks = ["Succeeded"]
                }
              }
            }
            runtimeConfiguration = {
              concurrency = {
                repetitions = 10
              }
            }
            runAfter = {
              InitializeInstanceAndDisksArray = ["Succeeded"]
            }
          }
          InitializeLun = {
            type = "InitializeVariable"
            inputs = {
              variables = [
                {
                  name  = "DiskLun"
                  type  = "integer"
                  value = 0
                }
              ]
            }
            runAfter = {
              ForEachInstanceCreateDisks = ["Succeeded"]
            }
          }
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
            runAfter = {
              InitializeLun = ["Succeeded"]
            }
          }
          InitializeTargetInstancesArray = {
            type = "InitializeVariable"
            inputs = {
              variables = [
                {
                  name  = "TargetInstances"
                  type  = "array"
                  value = []
                }
              ]
            }
            runAfter = {
              InitializeDisksArray = ["Succeeded"]
            }
          }
          InitializeScannerMachine = {
            type = "InitializeVariable"
            inputs = {
              variables = [
                {
                  name  = "ScannerMachine"
                  type  = "object"
                  value = {}
                }
              ]
            }
            runAfter = {
              InitializeTargetInstancesArray = ["Succeeded"]
            }
          }
          ForEachInstanceDisksSanitize = {
            type    = "Foreach"
            foreach = "@variables('InstanceAndDisks')"
            actions = {
              ForEachCreatedDisk = {
                type    = "Foreach"
                foreach = "@items('ForEachInstanceDisksSanitize')['disks']"
                actions = {
                  PushDisk = {
                    type = "AppendToArrayVariable"
                    inputs = {
                      name = "Disks"
                      value = {
                        lun = "@variables('DiskLun')"
                        managedDisk = {
                          id = "@item()['disk']['id']"
                        }
                        createOption            = "Attach"
                        deleteOption            = "Delete"
                        caching                 = "None"
                        writeAcceleratorEnabled = false
                      }
                    }
                    runAfter = {}
                  }
                  IncrementDiskLun = {
                    type = "IncrementVariable"
                    inputs = {
                      name  = "DiskLun"
                      value = 1
                    }
                    runAfter = {
                      PushDisk = ["Succeeded"]
                    }
                  }
                }
                runtimeConfiguration = {
                  concurrency = {
                    repetitions = 1
                  }
                }
                runAfter = {}
              }
              AddToTargetInstances = {
                type = "AppendToArrayVariable"
                inputs = {
                  name  = "TargetInstances"
                  value = "@items('ForEachInstanceDisksSanitize')['instance']"
                }
                runAfter = {
                  ForEachCreatedDisk = ["Succeeded"]
                }
              }
            }
            runtimeConfiguration = {
              concurrency = {
                repetitions = 1
              }
            }
            runAfter = {
              InitializeScannerMachine = ["Succeeded"]
            }
          }
          GetSubnet = {
            type = "Http"
            inputs = {
              uri = "${local.function_app_url}/api/arm/network"
              headers = {
                "Content-Type" = "application/json"
              }
              body = {
                resource = "subnets"
                method   = "get"
                parameters = [
                  "qualys-snapshot-scanner",
                  "qualys-virtual-network-@{triggerBody()['location']}",
                  "qualys-subnet-@{triggerBody()['location']}",
                ]
              }
              method         = "POST"
              authentication = local.msi_auth
              retryPolicy    = local.fixed_retry_3
            }
            runAfter = {
              ForEachInstanceDisksSanitize = ["Succeeded"]
            }
          }
          CreatePublicIp = {
            type = "Http"
            inputs = {
              uri = "${local.function_app_url}/api/arm/network"
              headers = {
                "Content-Type" = "application/json"
              }
              body = {
                resource = "publicIPAddresses"
                method   = "beginCreateOrUpdateAndWait"
                parameters = [
                  "qualys-snapshot-scanner",
                  "qualys-public-ip-@{variables('Id')}",
                  {
                    location = "@{triggerBody()['location']}"
                    sku = {
                      name = "Standard"
                    }
                    publicIPAllocationMethod = "Static"
                    dnsSettings = {
                      domainNameLabel = "qualys-domain-@{toLower(variables('Id'))}"
                    }
                    tags = local.runtime_tags
                  },
                ]
              }
              method         = "POST"
              authentication = local.msi_auth
              retryPolicy    = local.fixed_retry_3
            }
            runAfter = {
              GetSubnet = ["Succeeded"]
            }
          }
          CreateNic = {
            type = "Http"
            inputs = {
              uri = "${local.function_app_url}/api/arm/network"
              headers = {
                "Content-Type" = "application/json"
              }
              body = {
                resource = "networkInterfaces"
                method   = "beginCreateOrUpdateAndWait"
                parameters = [
                  "qualys-snapshot-scanner",
                  "qualys-nic-@{variables('Id')}",
                  {
                    location = "@triggerBody()['location']"
                    ipConfigurations = [
                      {
                        name                      = "Ipv4config"
                        privateIPAllocationMethod = "Dynamic"
                        subnet = {
                          id = "@body('GetSubnet')['id']"
                        }
                        publicIPAddress = {
                          id           = "@body('CreatePublicIp')['id']"
                          deleteOption = "Delete"
                        }
                      }
                    ]
                    tags = local.runtime_tags
                  },
                ]
              }
              method         = "POST"
              authentication = local.msi_auth
              retryPolicy    = local.fixed_retry_3
            }
            runAfter = {
              CreatePublicIp = ["Succeeded"]
            }
          }
          GetScannerImage = {
            type = "Http"
            inputs = {
              uri = "${local.function_app_url}/api/db/query"
              headers = {
                "Content-Type" = "application/json"
              }
              body = {
                container = "config"
                body = {
                  query        = "SELECT VALUE c.data FROM c WHERE c.type = \"image\""
                  partitionKey = "image"
                }
              }
              method         = "POST"
              authentication = local.msi_auth
              retryPolicy    = local.fixed_retry_3
            }
            runAfter = {
              CreateNic = ["Succeeded"]
            }
          }
          LaunchScannerMachine = {
            type = "Http"
            inputs = {
              uri = "${local.function_app_url}/api/arm/compute"
              headers = {
                "Content-Type" = "application/json"
              }
              body = {
                resource = "virtualMachines"
                method   = "beginCreateOrUpdate"
                parameters = [
                  "qualys-snapshot-scanner",
                  "qualys-vm-scanner-@{variables('Id')}",
                  {
                    location = "@triggerBody()['location']"
                    hardwareProfile = {
                      vmSize = "@if(equals('${var.scanners_per_location}', '4'), 'Standard_B2s', if(equals('${var.scanners_per_location}', '8'), 'Standard_B4ms', if(equals('${var.scanners_per_location}', '16'), 'Standard_B8ms', 'Standard_B1s')))"
                    }
                    storageProfile = {
                      imageReference = {
                        communityGalleryImageId = "@body('GetScannerImage')['resources'][0]"
                      }
                      osDisk = {
                        createOption            = "FromImage"
                        deleteOption            = "Delete"
                        caching                 = "None"
                        writeAcceleratorEnabled = false
                        managedDisk = {
                          storageAccountType = "StandardSSD_LRS"
                        }
                      }
                    }
                    networkProfile = {
                      networkInterfaces = [
                        {
                          id           = "/subscriptions/${var.subscription_id}/resourceGroups/qualys-snapshot-scanner/providers/Microsoft.Network/networkInterfaces/qualys-nic-@{variables('Id')}"
                          deleteOption = "Delete"
                        }
                      ]
                    }
                    tags = local.runtime_tags
                  },
                ]
              }
              method         = "POST"
              authentication = local.msi_auth
              retryPolicy    = local.fixed_retry_3
            }
            runAfter = {
              GetScannerImage = ["Succeeded"]
            }
          }
          WaitUntilScannerMachineLaunch = {
            type       = "Until"
            expression = "@and(equals(outputs('CheckVMStatus')['statusCode'], 200),equals(body('CheckVMStatus')['provisioningState'], 'Succeeded'))"
            actions = {
              WaitForVM = {
                type = "Wait"
                inputs = {
                  interval = {
                    count = 60
                    unit  = "Second"
                  }
                }
                runAfter = {}
              }
              CheckVMStatus = {
                type = "Http"
                inputs = {
                  uri = "${local.function_app_url}/api/arm/compute"
                  headers = {
                    "Content-Type" = "application/json"
                  }
                  body = {
                    resource   = "virtualMachines"
                    method     = "get"
                    parameters = ["qualys-snapshot-scanner", "qualys-vm-scanner-@{variables('Id')}"]
                  }
                  method         = "POST"
                  authentication = local.msi_auth
                  retryPolicy    = local.fixed_retry_3
                }
                runAfter = {
                  WaitForVM = ["Succeeded"]
                }
              }
            }
            limit = {
              count   = 10
              timeout = "PT600S"
            }
            runAfter = {
              LaunchScannerMachine = ["Succeeded"]
            }
          }
          SetScannerMachineVariable = {
            type = "SetVariable"
            inputs = {
              name  = "ScannerMachine"
              value = "@body('CheckVMStatus')"
            }
            runAfter = {
              WaitUntilScannerMachineLaunch = ["Succeeded"]
            }
          }
          AttachDisks = {
            type = "Http"
            inputs = {
              uri = "${local.function_app_url}/api/arm/compute"
              headers = {
                "Content-Type" = "application/json"
              }
              body = {
                resource = "virtualMachines"
                method   = "beginUpdateAndWait"
                parameters = [
                  "qualys-snapshot-scanner",
                  "qualys-vm-scanner-@{variables('Id')}",
                  {
                    storageProfile = {
                      dataDisks          = "@variables('Disks')"
                      diskControllerType = "SCSI"
                    }
                  },
                ]
              }
              method         = "POST"
              authentication = local.msi_auth
              retryPolicy    = local.fixed_retry_3
            }
            runAfter = {
              SetScannerMachineVariable = ["Succeeded"]
            }
          }
          ExecuteScan = {
            type = "Workflow"
            inputs = {
              host = {
                workflow = {
                  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Logic/workflows/${local.workflow_prefix}-run-commands-${var.deployment_id}"
                }
                triggerName = "HttpTrigger"
              }
              headers = {
                "content-type" = "application/json"
              }
              body = {
                parentId   = "@variables('Id')"
                name       = "qualys-vm-scanner-@{variables('Id')}"
                fqdn       = "@body('CreatePublicIp')['dnsSettings']['fqdn']"
                token      = "@{base64(workflow()['run']['name'])}"
                vms        = "@variables('TargetInstances')"
                vmIds      = "@variables('VMIds')"
                resourceId = "@variables('ScannerMachine')['id']"
                location   = "@{triggerBody()['location']}"
              }
              retryPolicy = local.no_retry
            }
            limit = {
              timeout = "PT1800S"
            }
            runAfter = {
              AttachDisks = ["Succeeded"]
            }
          }
          ForEachInstanceUpdateStatus = {
            type    = "Foreach"
            foreach = "@body('ExecuteScan')['vms']"
            actions = {
              UpdateStatus = {
                type = "Http"
                inputs = {
                  uri = "${local.function_app_url}/api/db/update"
                  headers = {
                    "Content-Type" = "application/json"
                  }
                  body = {
                    container = "resource-inventory"
                    body = {
                      id           = "@{item()['id']}"
                      partitionKey = ["@{triggerBody()['location']}"]
                      ops = [
                        {
                          op    = "replace"
                          path  = "/state"
                          value = "@if(equals(item()['status'], bool('true')), 'ScanCompleted', 'ScanFailed')"
                        },
                        {
                          op    = "replace"
                          path  = "/error"
                          value = "@if(contains(item(), 'errorCode'), item()['errorCode'], '')"
                        },
                        {
                          op    = "replace"
                          path  = "/ttl"
                          value = "@mul(3600, int('${var.scan_interval_hours}'))"
                        },
                      ]
                    }
                  }
                  method         = "POST"
                  authentication = local.msi_auth
                  retryPolicy    = local.fixed_retry_3
                }
                runAfter = {}
              }
              UpdateScanStatus = {
                type = "Http"
                inputs = {
                  uri = "${local.function_app_url}/api/db/update"
                  headers = {
                    "Content-Type" = "application/json"
                  }
                  body = {
                    container = "inventory-scan-status"
                    body = {
                      id           = "@{item()['id']}-os"
                      partitionKey = ["os"]
                      ops = [
                        {
                          op    = "replace"
                          path  = "/scanStatus"
                          value = "@if(equals(item()['status'], bool('true')), 'SCAN_COMPLETED', 'SCAN_FAILED')"
                        },
                        {
                          op    = "replace"
                          path  = "/stateReason"
                          value = "@if(contains(item(), 'errorCode'), item()['errorCode'], '')"
                        },
                      ]
                    }
                  }
                  method         = "POST"
                  authentication = local.msi_auth
                  retryPolicy    = local.fixed_retry_3
                }
                runAfter = {
                  UpdateStatus = ["Succeeded"]
                }
              }
            }
            runtimeConfiguration = {
              concurrency = {
                repetitions = 10
              }
            }
            runAfter = {
              ExecuteScan = ["Succeeded"]
            }
          }
          GetSnapshots = {
            type = "Http"
            inputs = {
              uri = "${local.function_app_url}/api/db/query"
              headers = {
                "Content-Type" = "application/json"
              }
              body = {
                container = "resource-inventory"
                body = {
                  query        = "SELECT VALUE c.id FROM c WHERE c.id in (\"@{join(variables('VMIds'),'\",\"')}\") AND (c.state != \"SnapshotsCompleted\" OR c.retry = 3)"
                  partitionKey = "@{triggerBody()['location']}"
                }
              }
              method         = "POST"
              authentication = local.msi_auth
              retryPolicy    = local.fixed_retry_3
            }
            runAfter = {
              ForEachInstanceUpdateStatus = ["Succeeded", "TIMEDOUT", "FAILED", "SKIPPED"]
            }
          }
          GetSnapshotsArray = {
            type = "Http"
            inputs = {
              uri = "${local.function_app_url}/api/format/get-snapshots-by-ids"
              headers = {
                "Content-Type" = "application/json"
              }
              body = {
                ids = "@body('GetSnapshots')['resources']"
                vms = "@triggerBody()['instances']"
              }
              method         = "POST"
              authentication = local.msi_auth
              retryPolicy    = local.fixed_retry_3
            }
            runAfter = {
              GetSnapshots = ["Succeeded"]
            }
          }
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
                force     = true
                parentId  = "@variables('Id')"
                location  = "@triggerBody()['location']"
                snapshots = "@body('GetSnapshotsArray')"
              }
              retryPolicy = local.no_retry
            }
            limit = {
              timeout = "PT300S"
            }
            runAfter = {
              GetSnapshotsArray = ["Succeeded"]
            }
          }
          DeleteVM = {
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
                force    = true
                parentId = "@variables('Id')"
                location = "@triggerBody()['location']"
                vms      = ["@variables('ScannerMachine')"]
              }
              retryPolicy = local.no_retry
            }
            limit = {
              timeout = "PT300S"
            }
            runAfter = {
              ForEachInstanceUpdateStatus = ["Succeeded", "TIMEDOUT", "FAILED", "SKIPPED"]
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
                message = "@{actions('ForEachInstanceUpdateStatus')['status']}"
              }
            }
            runAfter = {
              ForEachInstanceUpdateStatus = ["Succeeded"]
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
                message = "@{actions('ForEachInstanceUpdateStatus')['status']}"
              }
            }
            runAfter = {
              DeleteVM = ["Succeeded", "TIMEDOUT", "FAILED", "SKIPPED"]
            }
          }
        }
      }
    }
  }

  tags = var.tags
}
