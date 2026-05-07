# Karpenter IAM and SQS resources
#
# NOTE: Set var.karpenter_enabled = true to activate.
# Estimated cost: SQS ~$0/month (Free Tier), EC2 nodes vary.

# SQS Queue for EC2 interruption notifications
resource "aws_sqs_queue" "karpenter_interruption" {
  count                     = var.karpenter_enabled ? 1 : 0
  name                      = "${var.project_name}-karpenter"
  message_retention_seconds = 300

  tags = {
    Name      = "${var.project_name}-karpenter"
    ManagedBy = "terraform"
  }
}

# IAM Role for Karpenter controller
resource "aws_iam_role" "karpenter_controller" {
  count = var.karpenter_enabled ? 1 : 0
  name  = "${var.project_name}-karpenter-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider}:aud" = "sts.amazonaws.com"
          "${var.oidc_provider}:sub" = "system:serviceaccount:kube-system:karpenter"
        }
      }
    }]
  })
}

# Karpenter controller policy
resource "aws_iam_role_policy" "karpenter_controller" {
  count = var.karpenter_enabled ? 1 : 0
  name  = "karpenter-controller"
  role  = aws_iam_role.karpenter_controller[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:CreateLaunchTemplate",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:CreateTags",
          "iam:PassRole",
          "ssm:GetParameter",
          "pricing:GetProducts",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage"
        ]
        Resource = "*"
      }
    ]
  })
}
