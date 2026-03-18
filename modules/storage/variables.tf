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

variable "scanner_identity_id" {
  description = "Resource ID of the scanner managed identity"
  type        = string
}

variable "scanner_identity_principal_id" {
  description = "Principal ID of the scanner managed identity"
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoints"
  type        = string
}

variable "blob_dns_zone_id" {
  description = "ID of the blob private DNS zone"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}
