variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "deployment_id" {
  description = "Deployment identifier used in role names (5 characters recommended, must match the main deployment)"
  type        = string
}

variable "role_boundary" {
  description = "Scope for custom RBAC role assignability. Leave empty to use subscription scope, or set to a management group ID for tenant-wide scanning."
  type        = string
  default     = ""
}
