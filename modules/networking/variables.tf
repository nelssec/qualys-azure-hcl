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

variable "target_locations" {
  description = "Azure regions to scan VMs in"
  type        = list(string)
}

variable "target_cloud" {
  description = "Azure cloud environment"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}
