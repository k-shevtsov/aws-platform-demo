# GitHub Actions OIDC Identity Provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name      = "${var.project_name}-github-oidc"
    ManagedBy = "terraform"
  }
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-github-actions-role"
    ManagedBy = "terraform"
  }
}

# Policy for GitHub Actions — Terraform operations
resource "aws_iam_role_policy" "github_actions_terraform" {
  name = "terraform-operations"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # EC2
          "ec2:*",
          # VPC
          "vpc:*",
          # IAM (limited)
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:ListRoles",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:GetRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:TagRole",
          "iam:UntagRole",
          # ECR
          "ecr:*",
          # S3 — Terraform state
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          # DynamoDB — state locking
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable",
          "dynamodb:CreateTable",
          "dynamodb:TagResource",
          "dynamodb:DescribeContinuousBackups",
          "dynamodb:ListTagsOfResource",
          "dynamodb:DescribeTimeToLive",
          # CloudWatch
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:ListTagsLogGroup",
          "logs:PutRetentionPolicy",
          "logs:TagLogGroup",
          "logs:TagResource",
          "logs:ListTagsForResource",
          # Secrets Manager
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:ListSecrets",
          "secretsmanager:PutSecretValue",
          "secretsmanager:TagResource",
          "secretsmanager:GetResourcePolicy",
          # Config
          "config:*",
          "s3:GetBucketAcl",
          "s3:PutBucketPolicy",
          "s3:GetBucketPolicy",
          # CloudTrail
          "cloudtrail:*",
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketCORS",
          "s3:GetBucketWebsite",
          "s3:GetBucketVersioning",
          "s3:GetBucketLogging",
          "s3:GetBucketObjectLockConfiguration",
          "s3:GetBucketRequestPayment",
          "s3:GetReplicationConfiguration",
          "s3:GetAccelerateConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:GetBucketTagging",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketNotification"
        ]
        Resource = "*"
      }
    ]
  })
}
