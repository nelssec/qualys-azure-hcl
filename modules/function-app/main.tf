locals {
  target_locations_set = toset(var.target_locations)
}

resource "azurerm_log_analytics_workspace" "main" {
  count = var.debug_enabled ? 1 : 0

  name                = "qualys-logs-${var.deployment_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "main" {
  count = var.debug_enabled ? 1 : 0

  name                = "qualys-insights-${var.deployment_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.main[0].id
  tags                = var.tags
}

resource "azurerm_service_plan" "main" {
  name                = "qualys-asp-${var.deployment_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "P1v2"
  tags                = var.tags
}

resource "azurerm_linux_function_app" "main" {
  name                                           = "qualys-snapshot-scanner-v3-${var.deployment_id}"
  location                                       = var.location
  resource_group_name                            = var.resource_group_name
  service_plan_id                                = azurerm_service_plan.main.id
  storage_account_name                           = var.storage_account_name
  storage_account_access_key                     = var.storage_account_key
  https_only                                     = true
  virtual_network_subnet_id                      = var.function_app_subnet_id
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type         = "UserAssigned"
    identity_ids = [var.scanner_identity_id]
  }

  site_config {
    ftps_state          = "Disabled"
    minimum_tls_version = "1.2"

    application_stack {
      node_version = "18"
    }
  }

  app_settings = {
    AZURE_CLIENT_ID                       = var.scanner_identity_client_id
    SUBSCRIPTION_ID                       = var.subscription_id
    FUNCTIONS_WORKER_RUNTIME              = "node"
    WEBSITE_NODE_DEFAULT_VERSION          = "~18"
    WEBSITE_RUN_FROM_PACKAGE              = "1"
    COSMOS_ENDPOINT                       = var.cosmos_db_endpoint
    COSMOS_DATABASE                       = var.cosmos_db_name
    KEY_VAULT_URI                         = var.key_vault_uri
    QENDPOINT                             = var.qualys_endpoint
    SCAN_INTERVAL_HOURS                   = tostring(var.scan_interval_hours)
    POLL_INTERVAL_HOURS                   = tostring(var.poll_interval_hours)
    LOCATION_CONCURRENCY                  = tostring(var.location_concurrency)
    SCANNERS_PER_LOCATION                 = tostring(var.scanners_per_location)
    APP_VERSION                           = var.app_version
    ALL_TAGS                              = join(",", var.must_have_tags)
    ANY_TAGS                              = join(",", var.at_least_one_tag)
    NONE_TAGS                             = join(",", var.none_tags)
    SCAN_PAUSE_INTERVAL                   = var.scanner_pause_interval
    SCAN_SAMPLING                         = tostring(var.scan_sampling)
    SAMPLING_GROUP_SCAN_PERCENTAGE        = var.sampling_group_scan_percentage
    APPINSIGHTS_INSTRUMENTATIONKEY        = var.debug_enabled ? azurerm_application_insights.main[0].instrumentation_key : ""
    APPLICATIONINSIGHTS_CONNECTION_STRING = var.debug_enabled ? azurerm_application_insights.main[0].connection_string : ""
  }

  tags = merge(var.tags, var.debug_enabled ? {
    "hidden-link: /app-insights-resource-id" = azurerm_application_insights.main[0].id
  } : {})
}

# Regional proxy function apps (one per target location)
resource "azurerm_service_plan" "regional" {
  for_each = local.target_locations_set

  name                = "qualys-asp-${each.value}-${var.deployment_id}"
  location            = each.value
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = var.tags
}

resource "azurerm_linux_function_app" "regional" {
  for_each = local.target_locations_set

  name                                           = "qualys-proxy-${each.value}-${var.deployment_id}"
  location                                       = each.value
  resource_group_name                            = var.resource_group_name
  service_plan_id                                = azurerm_service_plan.regional[each.value].id
  storage_account_name                           = var.regional_storage_account_names[each.value]
  storage_uses_managed_identity                  = true
  https_only                                     = true
  virtual_network_subnet_id                      = var.regional_function_app_subnet_ids[each.value]
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type         = "UserAssigned"
    identity_ids = [var.scanner_identity_id]
  }

  site_config {
    ftps_state             = "Disabled"
    minimum_tls_version    = "1.2"
    vnet_route_all_enabled = true

    application_stack {
      node_version = "18"
    }
  }

  app_settings = {
    AzureWebJobsStorage__accountName = var.regional_storage_account_names[each.value]
    AzureWebJobsStorage__clientId    = var.scanner_identity_client_id
    AzureWebJobsStorage__credential  = "managedidentity"
    FUNCTIONS_EXTENSION_VERSION      = "~4"
    AZURE_CLIENT_ID                  = var.scanner_identity_client_id
    SERVICE_SUBSCRIPTION_ID          = var.subscription_id
    TENANT_ID                        = var.tenant_id
    RESOURCE_GROUP_NAME              = var.resource_group_name
    UNIQUE_ID                        = var.deployment_id
  }

  tags = var.tags
}
