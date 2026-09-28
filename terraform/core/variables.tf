variable "project_id" { type = string }
variable "create_project" {
  type    = bool
  default = false
}
variable "billing_account" {
  type    = string
  default = null
}
variable "folder_id" {
  type    = string
  default = null
}
variable "admin_cidr" {
  type        = string
  description = "Trusted operator public IPv4 CIDR, normally /32. No 0.0.0.0/0."
  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "Set a specific trusted IPv4 CIDR."
  }
}
variable "machine_type" {
  type    = string
  default = "e2-standard-2"
}
variable "deletion_protection" {
  type    = bool
  default = true
}
variable "iam_bindings" {
  description = "Map role to explicitly supplied group/user/serviceAccount principals. No invented identities."
  type        = map(set(string))
  default     = {}
}
