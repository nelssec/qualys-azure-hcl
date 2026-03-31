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

variable "scanner_identity_id" {
  description = "Resource ID of the scanner managed identity"
  type        = string
}

variable "scanner_identity_client_id" {
  description = "Client ID of the scanner managed identity"
  type        = string
}

variable "function_app_subnet_id" {
  description = "Subnet ID for function app VNet integration"
  type        = string
}

variable "storage_account_name" {
  description = "Name of the storage account"
  type        = string
}

variable "storage_account_key" {
  description = "Primary access key of the storage account"
  type        = string
  sensitive   = true
}

variable "cosmos_db_endpoint" {
  description = "Document endpoint of the Cosmos DB account"
  type        = string
}

variable "cosmos_db_name" {
  description = "Name of the Cosmos DB database"
  type        = string
}

variable "key_vault_uri" {
  description = "Vault URI of the secrets Key Vault"
  type        = string
}

variable "qualys_endpoint" {
  description = "Qualys platform API endpoint"
  type        = string
}

variable "debug_enabled" {
  description = "Enable Application Insights and extended logging"
  type        = bool
}

variable "app_version" {
  description = "Application version"
  type        = string
}

variable "scan_interval_hours" {
  description = "Hours between scan cycles"
  type        = number
}

variable "poll_interval_hours" {
  description = "Hours between poll-based discovery cycles"
  type        = number
}

variable "location_concurrency" {
  description = "Maximum concurrent location scans"
  type        = number
}

variable "scanners_per_location" {
  description = "Scanner VMs per location"
  type        = number
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}

variable "must_have_tags" {
  description = "Tags that VMs must have to be scanned"
  type        = list(string)
  default     = []
}

variable "at_least_one_tag" {
  description = "VMs must have at least one of these tags to be scanned"
  type        = list(string)
  default     = []
}

variable "none_tags" {
  description = "VMs with any of these tags will be excluded from scanning"
  type        = list(string)
  default     = []
}

variable "scanner_pause_interval" {
  description = "Pause interval in seconds between scanner operations"
  type        = string
  default     = "10"
}

variable "scan_sampling" {
  description = "Enable scan sampling"
  type        = bool
  default     = false
}

variable "sampling_group_scan_percentage" {
  description = "Percentage of VMs to scan per cycle when sampling is enabled"
  type        = string
  default     = "10"
}

variable "target_locations" {
  description = "Azure regions to scan VMs in"
  type        = list(string)
  default     = []
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "regional_function_app_subnet_ids" {
  description = "Map of location to regional proxy function app subnet ID"
  type        = map(string)
  default     = {}
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
