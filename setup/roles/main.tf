terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

data "azurerm_client_config" "current" {}

locals {
  role_boundary = var.role_boundary != "" ? var.role_boundary : "/subscriptions/${var.subscription_id}"
}

module "roles" {
  source = "git::https://github.com/nelssec/qualys-azure-hcl.git//modules/roles?ref=main"

  deployment_id = var.deployment_id
  role_boundary = local.role_boundary
}

output "function_app_role_id" {
  description = "Function App custom RBAC role ID — pass this to the main deployment"
  value       = module.roles.function_app_role_id
}

output "logic_app_role_id" {
  description = "Logic App custom RBAC role ID — pass this to the main deployment"
  value       = module.roles.logic_app_role_id
}

output "target_scanner_role_id" {
  description = "Target Scanner custom RBAC role ID — pass this to the main deployment"
  value       = module.roles.target_scanner_role_id
}
