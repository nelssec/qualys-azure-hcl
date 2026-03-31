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

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "logic_app_identity_id" {
  description = "Resource ID of the logic app managed identity"
  type        = string
}

variable "secrets_key_vault_name" {
  description = "Name of the secrets Key Vault"
  type        = string
}

variable "qualys_token_secret_name" {
  description = "Name of the Qualys token secret in Key Vault"
  type        = string
}

variable "qualys_endpoint" {
  description = "Qualys platform API endpoint"
  type        = string
}

variable "function_app_hostname" {
  description = "Default hostname of the Function App"
  type        = string
}

variable "storage_account_name" {
  description = "Name of the storage account"
  type        = string
}

variable "storage_container_name" {
  description = "Name of the function app packages blob container"
  type        = string
}

variable "event_based_discovery" {
  description = "Enable event-based VM discovery"
  type        = bool
}

variable "app_version" {
  description = "Application version"
  type        = string
}

variable "poll_interval_hours" {
  description = "Hours between poll-based discovery cycles"
  type        = number
  default     = 4
}

variable "scan_interval_hours" {
  description = "Hours between scan cycles"
  type        = number
  default     = 24
}

variable "location_concurrency" {
  description = "Maximum concurrent location scans"
  type        = number
  default     = 5
}

variable "scanners_per_location" {
  description = "Scanner VMs per location"
  type        = number
  default     = 1
}

variable "target_cloud" {
  description = "Azure cloud environment for storage suffix lookup"
  type        = string
  default     = "AzureCloud"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}

variable "runtime_resource_tags" {
  description = "Additional tags applied to runtime-created resources (scanner VMs, disks, snapshots, NICs, public IPs)"
  type        = map(string)
  default     = {}
}

variable "target_locations" {
  description = "Azure regions to scan VMs in"
  type        = list(string)
  default     = []
}

variable "regional_storage_account_names" {
  description = "Map of location to regional storage account name"
  type        = map(string)
  default     = {}
}

variable "regional_artifact_container_names" {
  description = "Map of location to regional artifact container name"
  type        = map(string)
  default     = {}
}

variable "regional_function_app_names" {
  description = "Map of location to regional proxy function app name"
  type        = map(string)
  default     = {}
}

variable "regional_function_app_hostnames" {
  description = "Map of location to regional proxy function app hostname"
  type        = map(string)
  default     = {}
}
