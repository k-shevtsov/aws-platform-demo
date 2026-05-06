variable "project_name"    { type = string }
variable "environment"     { type = string }
variable "config_enabled"  {
  type        = bool
  default     = false
  description = "Enable AWS Config. Costs ~$9/month. Set true to activate compliance scanning."
}
variable "config_s3_bucket" {
  type        = string
  default     = ""
  description = "S3 bucket for Config delivery channel (required when config_enabled=true)"
}
