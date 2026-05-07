variable "project_name"       { type = string }
variable "karpenter_enabled"  {
  type        = bool
  default     = false
  description = "Enable Karpenter. Requires OIDC provider. EC2 costs apply."
}
variable "oidc_provider_arn" {
  type    = string
  default = ""
}
variable "oidc_provider" {
  type    = string
  default = ""
}
