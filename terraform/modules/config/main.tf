# ──────────────────────────────────────────────────────────────
# AWS Config Rules — Security Compliance
#
# NOTE: AWS Config is DISABLED in this demo to stay within
# Free Tier. Estimated cost: ~$9/month (10 rules × ~100 evals/day).
#
# To enable: set var.config_enabled = true
# All rules are production-ready and follow CIS AWS Benchmark.
# ──────────────────────────────────────────────────────────────

# Config Recorder (required for all rules)
resource "aws_config_configuration_recorder" "main" {
  count = var.config_enabled ? 1 : 0
  name  = "${var.project_name}-recorder"

  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  count          = var.config_enabled ? 1 : 0
  name           = "${var.project_name}-delivery"
  s3_bucket_name = var.config_s3_bucket

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  count      = var.config_enabled ? 1 : 0
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# IAM Role for Config
resource "aws_iam_role" "config" {
  count = var.config_enabled ? 1 : 0
  name  = "${var.project_name}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = var.config_enabled ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# ── Rule 1: No unrestricted SSH (CIS 4.1) ───────────────────
resource "aws_config_config_rule" "no_unrestricted_ssh" {
  count = var.config_enabled ? 1 : 0
  name  = "${var.project_name}-no-unrestricted-ssh"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

# ── Rule 2: S3 buckets not publicly accessible ───────────────
resource "aws_config_config_rule" "s3_bucket_public_access" {
  count = var.config_enabled ? 1 : 0
  name  = "${var.project_name}-s3-no-public-access"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_LEVEL_PUBLIC_ACCESS_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

# ── Rule 3: EBS volumes encrypted ───────────────────────────
resource "aws_config_config_rule" "ebs_encrypted" {
  count = var.config_enabled ? 1 : 0
  name  = "${var.project_name}-ebs-encrypted"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

# ── Rule 4: IAM root access key check ───────────────────────
resource "aws_config_config_rule" "iam_root_access_key" {
  count = var.config_enabled ? 1 : 0
  name  = "${var.project_name}-iam-no-root-access-key"

  source {
    owner             = "AWS"
    source_identifier = "IAM_ROOT_ACCESS_KEY_CHECK"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

# ── Rule 5: MFA enabled for root ────────────────────────────
resource "aws_config_config_rule" "mfa_enabled_for_root" {
  count = var.config_enabled ? 1 : 0
  name  = "${var.project_name}-mfa-enabled-root"

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

# ── Rule 6: CloudTrail enabled ───────────────────────────────
resource "aws_config_config_rule" "cloudtrail_enabled" {
  count = var.config_enabled ? 1 : 0
  name  = "${var.project_name}-cloudtrail-enabled"

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}
