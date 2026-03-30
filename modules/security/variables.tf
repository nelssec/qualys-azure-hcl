variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for deployment"
  type        = string
}

variable "deployment_id" {
  description = "Unique deployment identifier for resource naming"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "deployer_object_id" {
  description = "Object ID of the deploying user or service principal"
  type        = string
}

variable "qualys_subscription_token" {
  description = "Qualys subscription token"
  type        = string
  sensitive   = true
}

variable "target_locations" {
  description = "Azure regions to scan VMs in"
  type        = list(string)
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}
