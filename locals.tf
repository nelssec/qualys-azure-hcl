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

  common_tags = merge({
    App        = "qualys-snapshot-scanner"
    AppVersion = var.app_version
    Name       = "Qualys Snapshot Scanner"
  }, var.tags)
}
