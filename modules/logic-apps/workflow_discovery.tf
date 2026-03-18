resource "azapi_resource" "poll_based_discover" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-poll-based-discover-vms-v2-${var.deployment_id}"
  location  = var.location
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"

  depends_on = [azapi_resource.discover_resources]

  body = {
    identity = local.identity_block
    properties = {
      state = "Enabled"
      definition = {
        "$schema"      = local.workflow_schema
        contentVersion = "1.0.0.0"
        parameters     = {}
        triggers = {
          Poll = {
            type = "Recurrence"
            recurrence = {
              frequency = "Hour"
              interval  = var.poll_interval_hours
            }
            runtimeConfiguration = {
              concurrency = {
                runs = 1
              }
            }
          }
        }
        actions = {
          PrepareJobsForDiscoverVMs = {
            type = "Http"
            inputs = {
              uri = "${local.function_app_url}/api/functions/DiscoveryTasksOrchestrator"
              headers = {
                "Content-Type" = "application/json"
              }
              body = {
                workflow = "@{last(split(workflow().run.id, '/'))}"
              }
              method         = "POST"
              authentication = local.msi_auth
              retryPolicy    = local.fixed_retry_3
            }
            runAfter = {}
          }
          IfJobsPrepared = {
            type = "If"
            expression = {
              and = [
                {
                  equals = ["@outputs('PrepareJobsForDiscoverVMs')['statusCode']", 200]
                },
                {
                  not = {
                    equals = ["@body('PrepareJobsForDiscoverVMs')", null]
                  }
                }
              ]
            }
            actions = {
              ExecuteTasks = {
                type = "Workflow"
                inputs = {
                  host = {
                    workflow = {
                      id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Logic/workflows/qualys-discover-resources-v2-${var.deployment_id}"
                    }
                    triggerName = "HttpTrigger"
                  }
                  headers = {
                    "content-type" = "application/json"
                  }
                  body        = {}
                  retryPolicy = local.no_retry
                }
                limit = {
                  timeout = "PT60S"
                }
                runAfter = {}
              }
              SuppressErrorExecuteTasks = {
                type   = "Compose"
                inputs = ""
                runAfter = {
                  ExecuteTasks = ["TIMEDOUT", "FAILED"]
                }
              }
            }
            runAfter = {
              PrepareJobsForDiscoverVMs = ["Succeeded"]
            }
          }
          LogPrepareJobsForDiscoverVMs = {
            type = "Scope"
            actions = {
              PrepareJobsForDiscoverVMsEventLog = {
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
                        runId          = "@{workflow()['run']['name']}"
                        resource       = "FunctionApp"
                        location       = var.location
                        subscriptionId = var.subscription_id
                        state          = "PrepareJobsForDiscoverVMs"
                        input = {
                          workflow = "@{last(split(workflow().run.id, '/'))}"
                        }
                        output = {
                          PrepareJobsForDiscoverVMs = "@outputs('PrepareJobsForDiscoverVMs')"
                        }
                        error = "@if(equals(actions('PrepareJobsForDiscoverVMs')['status'], 'Succeeded'), false, true)"
                      }
                    }
                  }
                  method         = "POST"
                  authentication = local.msi_auth
                  retryPolicy    = local.no_retry
                }
                runAfter = {}
              }
              PrepareJobsForDiscoverVMsEventLogSuppressError = {
                type   = "Compose"
                inputs = ""
                runAfter = {
                  PrepareJobsForDiscoverVMsEventLog = ["TIMEDOUT", "FAILED"]
                }
              }
            }
            runAfter = {
              PrepareJobsForDiscoverVMs = ["Succeeded", "FAILED", "TIMEDOUT"]
            }
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "azapi_resource" "discover_resources" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-discover-resources-v2-${var.deployment_id}"
  location  = var.location
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"

  depends_on = [azapi_resource.create_snapshots]

  body = {
    identity = local.identity_block
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
          ExecuteTaks = {
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
                      query = "SELECT * FROM c WHERE c.status = 0 AND c.retry < 3 ORDER BY c._ts DESC, c.priority DESC OFFSET 0 LIMIT 50"
                      incr  = true
                      key   = "workflow"
                    }
                    container = "tasks"
                  }
                  method         = "POST"
                  authentication = local.msi_auth
                  retryPolicy    = local.fixed_retry_3
                }
                runAfter = {}
              }
              ForEachTask = {
                type    = "Foreach"
                foreach = "@body('Query').resources"
                actions = {
                  DiscoverVMs = {
                    type = "Http"
                    inputs = {
                      uri = "${local.function_app_url}/api/functions/DiscoverVMsOrchestrator"
                      headers = {
                        "Content-Type" = "application/json"
                      }
                      body           = "@item()"
                      method         = "POST"
                      authentication = local.msi_auth
                      retryPolicy    = local.fixed_retry_3
                    }
                    runAfter = {}
                  }
                  LogDiscoverVMs = {
                    type = "Scope"
                    actions = {
                      DiscoverVMsEventLog = {
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
                                runId          = "@{workflow()['run']['name']}"
                                resource       = "DurableFunction"
                                location       = "@item()['locations']"
                                subscriptionId = "@item()['subscription']"
                                state          = "DiscoverVMs"
                                input          = "@item()"
                                output = {
                                  DiscoverVMs = "@outputs('DiscoverVMs')"
                                }
                                error = "@if(equals(actions('DiscoverVMs')['status'], 'Succeeded'), false, true)"
                              }
                            }
                          }
                          method         = "POST"
                          authentication = local.msi_auth
                          retryPolicy    = local.no_retry
                        }
                        runAfter = {}
                      }
                      DiscoverVMsEventLogSuppressError = {
                        type   = "Compose"
                        inputs = ""
                        runAfter = {
                          DiscoverVMsEventLog = ["TIMEDOUT", "FAILED"]
                        }
                      }
                    }
                    runAfter = {
                      DiscoverVMs = ["Succeeded", "FAILED", "TIMEDOUT"]
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
              count   = 1000
              timeout = "PT1440S"
            }
            runAfter = {
              SuccessResponse = ["Succeeded"]
            }
          }
          CreateSnapshots = {
            type = "Workflow"
            inputs = {
              host = {
                workflow = {
                  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Logic/workflows/qualys-create-snapshots-v2-${var.deployment_id}"
                }
                triggerName = "HttpTrigger"
              }
              headers = {
                "content-type" = "application/json"
              }
              body        = {}
              retryPolicy = local.no_retry
            }
            limit = {
              timeout = "PT60S"
            }
            runAfter = {
              ExecuteTaks = ["Succeeded", "TIMEDOUT", "FAILED"]
            }
          }
          SuppressErrorCreateSnapshot = {
            type   = "Compose"
            inputs = ""
            runAfter = {
              CreateSnapshots = ["TIMEDOUT", "FAILED"]
            }
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "azapi_resource" "event_based_discover" {
  count     = var.event_based_discovery ? 1 : 0
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-event-based-discover-vms-v2-${var.deployment_id}"
  location  = var.location
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"

  depends_on = [azapi_resource.discover_resources, azapi_resource.create_snapshots]

  body = {
    identity = local.identity_block
    properties = {
      state = "Enabled"
      definition = {
        "$schema"      = local.workflow_schema
        contentVersion = "1.0.0.0"
        parameters     = {}
        triggers = {
          Poll = {
            type = "Recurrence"
            recurrence = {
              frequency = "Minute"
              interval  = 3
            }
            runtimeConfiguration = {
              concurrency = {
                runs = 10
              }
            }
          }
        }
        actions = {
          Until = {
            type       = "Until"
            expression = "@and(equals(outputs('FetchMessages')['statusCode'], 200),equals(length(body('FetchMessages')),0))"
            actions = {
              FetchMessages = {
                type = "Http"
                inputs = {
                  uri = "${local.function_app_url}/api/messages/list"
                  headers = {
                    "Content-Type" = "application/json"
                  }
                  body           = {}
                  method         = "POST"
                  authentication = local.msi_auth
                  retryPolicy = {
                    count    = 1
                    interval = "PT60S"
                    type     = "fixed"
                  }
                }
                runAfter = {}
              }
              HasMessage = {
                type = "If"
                expression = {
                  and = [
                    {
                      equals = ["@outputs('FetchMessages')['statusCode']", 200]
                    },
                    {
                      greater = ["@length(body('FetchMessages'))", 0]
                    }
                  ]
                }
                actions = {
                  GetTags = {
                    type = "Http"
                    inputs = {
                      uri = "${local.function_app_url}/api/format/parse-tags"
                      headers = {
                        "Content-Type" = "application/json"
                      }
                      body           = {}
                      method         = "POST"
                      authentication = local.msi_auth
                      retryPolicy    = local.fixed_retry_3
                    }
                    runAfter = {}
                  }
                  ExecuteTasks = {
                    type = "Workflow"
                    inputs = {
                      host = {
                        workflow = {
                          id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Logic/workflows/qualys-discover-resources-v2-${var.deployment_id}"
                        }
                        triggerName = "HttpTrigger"
                      }
                      headers = {
                        "content-type" = "application/json"
                      }
                      body        = {}
                      retryPolicy = local.no_retry
                    }
                    limit = {
                      timeout = "PT60S"
                    }
                    runAfter = {
                      GetTags = ["Succeeded"]
                    }
                  }
                  SuppressErrorExecuteTasks = {
                    type   = "Compose"
                    inputs = ""
                    runAfter = {
                      ExecuteTasks = ["TIMEDOUT", "FAILED"]
                    }
                  }
                  CreateSnapshots = {
                    type = "Workflow"
                    inputs = {
                      host = {
                        workflow = {
                          id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Logic/workflows/qualys-create-snapshots-v2-${var.deployment_id}"
                        }
                        triggerName = "HttpTrigger"
                      }
                      headers = {
                        "content-type" = "application/json"
                      }
                      body = {
                        parentId = "@workflow()['run']['name']"
                      }
                      retryPolicy = local.no_retry
                    }
                    limit = {
                      timeout = "PT60S"
                    }
                    runAfter = {
                      ExecuteTasks = ["Succeeded", "TIMEDOUT", "FAILED"]
                    }
                  }
                  SuppressErrorCreateSnapshot = {
                    type   = "Compose"
                    inputs = ""
                    runAfter = {
                      CreateSnapshots = ["TIMEDOUT", "FAILED"]
                    }
                  }
                }
                runAfter = {
                  FetchMessages = ["Succeeded"]
                }
              }
            }
            limit = {
              count   = 10
              timeout = "PT180S"
            }
            runAfter = {}
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "azapi_resource" "demand_based_discover" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "${local.workflow_prefix}-demand-based-discover-vms-v2-${var.deployment_id}"
  location  = var.location
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"

  depends_on = [azapi_resource.discover_resources, azapi_resource.create_snapshots]

  body = {
    identity = local.identity_block
    properties = {
      state = "Enabled"
      definition = {
        "$schema"      = local.workflow_schema
        contentVersion = "1.0.0.0"
        parameters     = {}
        triggers = {
          Poll = {
            type = "Recurrence"
            recurrence = {
              frequency = "Minute"
              interval  = 3
            }
            runtimeConfiguration = {
              concurrency = {
                runs = 10
              }
            }
          }
        }
        actions = {
          FetchTasks = {
            type = "Http"
            inputs = {
              uri = "${local.function_app_url}/api/app/tasks"
              headers = {
                "Content-Type" = "application/json"
              }
              body = {
                workflow = "@{last(split(workflow().run.id, '/'))}"
              }
              method         = "POST"
              authentication = local.msi_auth
              retryPolicy    = local.fixed_retry_3
            }
            runAfter = {}
          }
          HasMessage = {
            type = "If"
            expression = {
              and = [
                {
                  equals = ["@outputs('FetchTasks')['statusCode']", 200]
                },
                {
                  greater = ["@body('FetchTasks')['count']", 0]
                }
              ]
            }
            actions = {
              ExecuteTasks = {
                type = "Workflow"
                inputs = {
                  host = {
                    workflow = {
                      id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Logic/workflows/qualys-discover-resources-v2-${var.deployment_id}"
                    }
                    triggerName = "HttpTrigger"
                  }
                  headers = {
                    "content-type" = "application/json"
                  }
                  body        = {}
                  retryPolicy = local.no_retry
                }
                limit = {
                  timeout = "PT60S"
                }
                runAfter = {}
              }
              SuppressErrorExecuteTasks = {
                type   = "Compose"
                inputs = ""
                runAfter = {
                  ExecuteTasks = ["TIMEDOUT", "FAILED"]
                }
              }
              CreateSnapshots = {
                type = "Workflow"
                inputs = {
                  host = {
                    workflow = {
                      id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Logic/workflows/qualys-create-snapshots-v2-${var.deployment_id}"
                    }
                    triggerName = "HttpTrigger"
                  }
                  headers = {
                    "content-type" = "application/json"
                  }
                  body = {
                    parentId = "@workflow()['run']['name']"
                  }
                  retryPolicy = local.no_retry
                }
                limit = {
                  timeout = "PT60S"
                }
                runAfter = {
                  ExecuteTasks = ["Succeeded", "TIMEDOUT", "FAILED"]
                }
              }
              SuppressErrorCreateSnapshot = {
                type   = "Compose"
                inputs = ""
                runAfter = {
                  CreateSnapshots = ["TIMEDOUT", "FAILED"]
                }
              }
            }
            runAfter = {
              FetchTasks = ["Succeeded"]
            }
          }
        }
      }
    }
  }

  tags = var.tags
}
