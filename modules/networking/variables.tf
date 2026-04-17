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

variable "existing_service_vnet_id" {
  description = "Use an existing VNet for service resources instead of creating one"
  type        = string
  default     = null
}

variable "existing_function_app_subnet_id" {
  description = "Use an existing subnet for the central function app"
  type        = string
  default     = null
}

variable "existing_private_endpoint_subnet_id" {
  description = "Use an existing subnet for private endpoints"
  type        = string
  default     = null
}

variable "existing_scanner_vnet_ids" {
  description = "Map of location to existing scanner VNet ID. When set, skips creating scanner VNets, peerings, and DNS links for those locations."
  type        = map(string)
  default     = {}
}

variable "existing_scanner_subnet_ids" {
  description = "Map of location to existing scanner subnet ID"
  type        = map(string)
  default     = {}
}

variable "existing_regional_function_app_subnet_ids" {
  description = "Map of location to existing proxy function app subnet ID (must be delegated to Microsoft.Web/serverFarms)"
  type        = map(string)
  default     = {}
}

variable "existing_regional_private_storage_subnet_ids" {
  description = "Map of location to existing private storage subnet ID"
  type        = map(string)
  default     = {}
}

variable "vnet_address_prefix" {
  description = "Address prefix for the service VNet (ignored when existing_service_vnet_id is set)"
  type        = string
  default     = "10.0.0.0/20"
}

variable "scanner_vnet_address_prefix" {
  description = "Base address prefix for scanner VNets (ignored when existing_scanner_vnet_ids is set)"
  type        = string
  default     = "10.1.0.0/16"
}
