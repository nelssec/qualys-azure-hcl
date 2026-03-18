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

variable "key_vault_id" {
  description = "Resource ID of the Key Vault"
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoints"
  type        = string
}

variable "keyvault_dns_zone_id" {
  description = "ID of the Key Vault private DNS zone"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}
