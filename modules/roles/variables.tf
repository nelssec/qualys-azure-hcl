variable "deployment_id" {
  description = "Unique deployment identifier for resource naming"
  type        = string
}

variable "role_boundary" {
  description = "Scope for custom RBAC role assignability (subscription or management group ID)"
  type        = string
}
