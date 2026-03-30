data "http" "deployer_ip" {
  url = "https://ifconfig.me/ip"
}

resource "random_string" "deployment_id" {
  count   = var.custom_deployment_id == "" ? 1 : 0
  length  = 5
  special = false
  upper   = false
  keepers = {
    subscription_id     = var.subscription_id
    resource_group_name = var.resource_group_name
  }
}

locals {
  deployment_id   = var.custom_deployment_id != "" ? var.custom_deployment_id : random_string.deployment_id[0].result
  role_boundary   = var.role_boundary != "" ? var.role_boundary : "/subscriptions/${var.subscription_id}"
  subscription_id = var.subscription_id

  deployer_object_id = var.deployer_principal_type == "ServicePrincipal" ? data.azuread_service_principal.deployer[0].object_id : data.azurerm_client_config.current.object_id

  function_app_role_id   = var.create_roles ? module.roles[0].function_app_role_id : var.existing_function_app_role_id
  logic_app_role_id      = var.create_roles ? module.roles[0].logic_app_role_id : var.existing_logic_app_role_id
  target_scanner_role_id = var.create_roles ? module.roles[0].target_scanner_role_id : var.existing_target_scanner_role_id

  common_tags = merge({
    App        = "qualys-snapshot-scanner"
    AppVersion = var.app_version
    Name       = "Qualys Snapshot Scanner"
  }, var.tags)
}
