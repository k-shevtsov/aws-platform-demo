variable "project_name"   { type = string }
variable "environment"    { type = string }
variable "config_enabled" {
  type        = bool
  default     = true
  description = "Enable AWS Config. Cost: ~$9/month."
}
variable "config_s3_bucket" {
  type        = string
  description = "S3 bucket for Config delivery channel"
}
