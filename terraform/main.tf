terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  # profile used locally only — CI uses AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY env vars
}

# ── VPC ─────────────────────────────────────────
module "vpc" {
  source             = "./modules/vpc"
  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  aws_region         = var.aws_region
}

# ── IAM ─────────────────────────────────────────
module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  environment  = var.environment
}

# ── ECR ─────────────────────────────────────────
module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
  environment  = var.environment
}

# ── EC2 + k3s ───────────────────────────────────
module "ec2" {
  source            = "./modules/ec2"
  project_name      = var.project_name
  environment       = var.environment
  subnet_id         = module.vpc.public_subnet_id
  security_group_id = module.vpc.security_group_id
  instance_type     = var.instance_type
  instance_profile  = module.iam.instance_profile_name
  ssh_allowed_cidr  = var.ssh_allowed_cidr
  ecr_registry_url  = module.ecr.registry_url
  elastic_ip_id     = module.vpc.elastic_ip_id
  elastic_ip        = module.vpc.elastic_ip
  ssh_public_key    = var.ssh_public_key
}

# DynamoDB table for Terraform state locking
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "${var.project_name}-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-tfstate-lock"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── GitHub Actions OIDC ──────────────────────────────────────
module "oidc" {
  source       = "./modules/oidc"
  project_name = var.project_name
  github_org   = "k-shevtsov"
  github_repo  = "aws-platform-demo"
}

# ── CloudWatch Log Groups ────────────────────────────────────
resource "aws_cloudwatch_log_group" "k3s_pods" {
  name              = "/aws-platform-demo/k3s/pods"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-k3s-pods"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "k3s_system" {
  name              = "/aws-platform-demo/k3s/system"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-k3s-system"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}


# ── AWS Config Rules (disabled in demo, ~$9/month to enable) ─
module "config" {
  source            = "./modules/config"
  project_name      = var.project_name
  environment       = var.environment
  config_enabled    = true
  config_s3_bucket  = "aws-platform-demo-config-658424926455"
}

# ── Karpenter (disabled in demo, EC2 costs apply) ────────────
module "karpenter" {
  source             = "./modules/karpenter"
  project_name       = var.project_name
  karpenter_enabled  = false  # set true to activate node autoprovisioning
  oidc_provider_arn  = module.oidc.provider_arn
  oidc_provider      = "token.actions.githubusercontent.com"
}

# ── CloudTrail ───────────────────────────────────────────────
module "cloudtrail" {
  source             = "./modules/cloudtrail"
  project_name       = var.project_name
  account_id         = "658424926455"
  cloudtrail_enabled = true
}
