# CloudTrail — AWS API activity logging
# Cost: ~$2/month (S3 storage for logs)

resource "aws_s3_bucket" "cloudtrail" {
  count  = var.cloudtrail_enabled ? 1 : 0
  bucket = "${var.project_name}-cloudtrail-${var.account_id}"

  tags = {
    Name      = "${var.project_name}-cloudtrail"
    ManagedBy = "terraform"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  count  = var.cloudtrail_enabled ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  count  = var.cloudtrail_enabled ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::${var.project_name}-cloudtrail-${var.account_id}"
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.project_name}-cloudtrail-${var.account_id}/AWSLogs/${var.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  count                         = var.cloudtrail_enabled ? 1 : 0
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail[0].id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true

  tags = {
    Name      = "${var.project_name}-trail"
    ManagedBy = "terraform"
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}
