output "trail_arn" {
  value = var.cloudtrail_enabled ? aws_cloudtrail.main[0].arn : ""
}
