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

variable "target_cloud" {
  description = "Azure cloud environment"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}

variable "service_vnet_id" {
  description = "ID of the existing service VNet"
  type        = string
}

variable "function_app_subnet_id" {
  description = "ID of the existing subnet for the central function app (must be delegated to Microsoft.Web/serverFarms)"
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "ID of the existing subnet for private endpoints"
  type        = string
}

variable "scanner_subnet_ids" {
  description = "Map of location to existing scanner subnet ID"
  type        = map(string)
}

variable "regional_function_app_subnet_ids" {
  description = "Map of location to existing proxy function app subnet ID (must be delegated to Microsoft.Web/serverFarms)"
  type        = map(string)
}

variable "regional_private_storage_subnet_ids" {
  description = "Map of location to existing private storage subnet ID"
  type        = map(string)
}
