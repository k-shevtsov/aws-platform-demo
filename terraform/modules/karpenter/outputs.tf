output "controller_role_arn" {
  value = var.karpenter_enabled ? aws_iam_role.karpenter_controller[0].arn : ""
}
output "interruption_queue_url" {
  value = var.karpenter_enabled ? aws_sqs_queue.karpenter_interruption[0].url : ""
}
