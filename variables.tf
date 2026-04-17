variable "subscription_id" {
  description = "Azure subscription ID for the deployment"
  type        = string
}

variable "location" {
  description = "Azure region for deployment"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name for deployment"
  type        = string
  default     = "qualys-scanner-rg"
}

variable "qualys_endpoint" {
  description = "Qualys platform API endpoint"
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

variable "target_cloud" {
  description = "Azure cloud environment"
  type        = string
  default     = "AzureCloud"
  validation {
    condition     = contains(["AzureCloud", "AzureUSGovernment", "AzureChinaCloud"], var.target_cloud)
    error_message = "Must be one of: AzureCloud, AzureUSGovernment, AzureChinaCloud."
  }
}

variable "debug_enabled" {
  description = "Enable Application Insights and extended logging"
  type        = bool
  default     = false
}

variable "event_based_discovery" {
  description = "Use event-based VM discovery"
  type        = bool
  default     = false
}

variable "scan_interval_hours" {
  description = "Hours between scan cycles"
  type        = number
  default     = 24
}

variable "poll_interval_hours" {
  description = "Hours between poll-based discovery cycles"
  type        = number
  default     = 4
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

variable "app_version" {
  description = "Application version"
  type        = string
  default     = "3.21.0-6"
}

variable "tags" {
  description = "Additional resource tags applied to all infrastructure resources"
  type        = map(string)
  default     = {}
}

variable "runtime_resource_tags" {
  description = "Additional tags applied to runtime-created resources (scanner VMs, disks, snapshots, NICs, public IPs)"
  type        = map(string)
  default     = {}
}

variable "custom_deployment_id" {
  description = "Custom deployment ID (5 characters recommended). If empty, one is auto-generated."
  type        = string
  default     = ""
}

variable "role_boundary" {
  description = "Role boundary for custom RBAC roles. Use subscription ID for single subscription, or management group ID for tenant-wide scanning."
  type        = string
  default     = ""
}

variable "create_roles" {
  description = "Create custom RBAC roles as part of this deployment. Set to false if roles were pre-created via setup/roles."
  type        = bool
  default     = true
}

variable "existing_function_app_role_id" {
  description = "Pre-existing Function App custom role ID. Required when create_roles is false."
  type        = string
  default     = ""
}

variable "existing_logic_app_role_id" {
  description = "Pre-existing Logic App custom role ID. Required when create_roles is false."
  type        = string
  default     = ""
}

variable "existing_target_scanner_role_id" {
  description = "Pre-existing Target Scanner custom role ID. Required when create_roles is false."
  type        = string
  default     = ""
}

variable "must_have_tags" {
  description = "Tags that VMs must have to be scanned (comma-joined for function app)"
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
  description = "Enable scan sampling to scan a percentage of VMs per cycle"
  type        = bool
  default     = false
}

variable "sampling_group_scan_percentage" {
  description = "Percentage of VMs to scan per cycle when sampling is enabled"
  type        = string
  default     = "10"
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

