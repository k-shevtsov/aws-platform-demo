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
