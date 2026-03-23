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
  default     = "3.20.0"
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

