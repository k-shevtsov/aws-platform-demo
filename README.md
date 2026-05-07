# AWS Platform Demo

> Production-grade AWS infrastructure provisioned with Terraform: VPC, EC2, IAM, ECR, k3s, CloudWatch, Secrets Manager, ESO — full cloud platform demo for portfolio.

[![Terraform](https://img.shields.io/badge/terraform-1.x-7B42BC.svg)](https://terraform.io)
[![AWS](https://img.shields.io/badge/AWS-eu--central--1-FF9900.svg)](https://aws.amazon.com)
[![k3s](https://img.shields.io/badge/kubernetes-k3s-326CE5.svg)](https://k3s.io)
[![OIDC](https://img.shields.io/badge/auth-OIDC-green.svg)](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

## What This Is

A cloud platform demo that provisions production-grade AWS infrastructure from scratch using Terraform modules, deploys k3s on EC2 Free Tier, and integrates a full observability and secrets management stack — all without long-lived AWS credentials.

## Architecture

```
Terraform (local/CI) → AWS eu-central-1
├── VPC (10.0.0.0/16)
│   ├── Public Subnet (10.0.1.0/24)
│   ├── Internet Gateway + Route Table
│   ├── Security Group (SSH, HTTP, HTTPS, k3s API, NodePort)
│   └── Elastic IP (static, survives EC2 recreation)
├── IAM
│   ├── EC2 Role (ECR + SSM + CloudWatch + Secrets Manager)
│   ├── Instance Profile
│   └── GitHub Actions OIDC Role (zero long-lived credentials)
├── ECR (aws-platform-demo)
│   └── Lifecycle policy: keep last 10 images, scan on push
├── S3 (Terraform state)
│   └── DynamoDB (state locking + encryption)
├── Secrets Manager
│   └── aws-platform-demo/demo-app/config
├── CloudWatch
│   ├── Log Group: /aws-platform-demo/k3s/pods (7d retention)
│   └── Log Group: /aws-platform-demo/k3s/system (7d retention)
└── EC2 t3.micro (Free Tier)
├── Ubuntu 24.04 LTS + 2GB swap
├── k3s v1.35.4 (TLS SAN for stable kubeconfig)
├── demo-app:v1.0.0 ← pulled from ECR
├── Fluent Bit DaemonSet → CloudWatch Logs
└── External Secrets Operator → Secrets Manager
```

## Stack

| Component | Technology | Details |
|-----------|-----------|---------|
| IaC | Terraform ~> 5.0 | Modular: vpc, ec2, iam, ecr, oidc, config, karpenter |
| Network | VPC + Subnet + IGW + SG + Elastic IP | eu-central-1a, static IP |
| Compute | EC2 t3.micro | Free Tier, Ubuntu 24.04 |
| Container Runtime | k3s v1.35.4 | TLS SAN, kubeconfig stable |
| Registry | Amazon ECR | Scan on push, lifecycle policy |
| State Backend | S3 + DynamoDB | Versioning + locking + encryption |
| CI Auth | GitHub Actions OIDC | Zero long-lived AWS credentials |
| Secrets | AWS Secrets Manager + ESO | SecretSynced: True |
| Observability | Fluent Bit + CloudWatch Logs | Structured JSON, 7d retention |
| Compliance | AWS Config rules module | 6 CIS rules, disabled by default |
| Autoscaling | Karpenter manifests | NodePool + EC2NodeClass, stub |

## Security Highlights

**Zero long-lived credentials** — GitHub Actions authenticates via OIDC:
GitHub Actions → sts:AssumeRoleWithWebIdentity → temporary credentials
No `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` in GitHub Secrets.

**Secrets never hardcoded** — AWS Secrets Manager + External Secrets Operator:
AWS Secrets Manager → ESO ClusterSecretStore → Kubernetes Secret (auto-synced 1h)

## Quick Start

```bash
git clone https://github.com/k-shevtsov/aws-platform-demo
cd aws-platform-demo

# Prerequisites: AWS CLI, Terraform >= 1.0, Docker, kubectl, helm

# 1. Configure AWS
aws configure --profile terraform-admin

# 2. Generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/aws-platform-demo -N ""

# 3. Create S3 backend bucket
aws s3 mb s3://aws-platform-demo-tfstate-<ACCOUNT_ID> \
  --region eu-central-1 --profile terraform-admin

aws dynamodb create-table \
  --table-name aws-platform-demo-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1 --profile terraform-admin

# 4. Deploy
cd terraform
terraform init
terraform apply -var="ssh_public_key=$(cat ~/.ssh/aws-platform-demo.pub)"

# 5. Get kubeconfig
ssh -i ~/.ssh/aws-platform-demo ubuntu@<ELASTIC_IP> \
  'sudo cat /etc/rancher/k3s/k3s.yaml' \
  | sed 's/127.0.0.1/<ELASTIC_IP>/' > ~/.kube/aws-platform-demo.yaml

kubectl --kubeconfig ~/.kube/aws-platform-demo.yaml get nodes
```

## CI/CD

| Workflow | Trigger | Action |
|----------|---------|--------|
| `terraform-plan.yml` | push/PR to `terraform/**` | init + validate + plan + PR comment |
| `terraform-scheduled.yml` | 22:00 UTC daily | `terraform destroy` (cost saving) |
| `terraform-scheduled.yml` | 07:00 UTC Mon-Fri | `terraform apply` (restore) |
| `terraform-scheduled.yml` | `workflow_dispatch` | manual apply/destroy |

## Terraform Modules

| Module | Resources | Status |
|--------|-----------|--------|
| `vpc` | VPC, Subnet, IGW, Route Table, SG, Elastic IP | ✅ Active |
| `iam` | EC2 Role, Instance Profile, CloudWatch + Secrets policies | ✅ Active |
| `ecr` | Repository, Lifecycle policy | ✅ Active |
| `ec2` | Instance, Key Pair, EIP association | ✅ Active |
| `oidc` | OIDC Provider, GitHub Actions IAM Role | ✅ Active |
| `config` | 6 CIS Config rules | ⚙️ Disabled (~$9/month) |
| `karpenter` | Controller IAM Role, SQS interruption queue | ⚙️ Disabled (EC2 costs) |

## Kubernetes Stack

```bash
kubectl get pods -A
# NAMESPACE          NAME                            READY
# default            demo-app-*                      1/1    # ECR → NodePort 30080
# logging            fluent-bit-*                    1/1    # → CloudWatch Logs
# external-secrets   external-secrets-*              1/1    # → Secrets Manager
```

## Cost

| Resource | Free Tier | Monthly |
|----------|-----------|---------|
| EC2 t3.micro | 750 hrs/month | $0 |
| S3 state | 5 GB free | $0 |
| ECR | 500 MB free | $0 |
| CloudWatch Logs | 5 GB free | $0 |
| Secrets Manager | 30-day trial | ~$0.40/secret |
| DynamoDB | 25 GB free | $0 |
| Elastic IP | Free when attached | $0 |
| **Total** | | **~$0-1/month** |

## Disabled Features (Cost-Documented)

**AWS Config** (`config_enabled = true`): 6 CIS Benchmark rules — no SSH 0.0.0.0/0, S3 no public access, EBS encrypted, IAM root key check, MFA for root, CloudTrail enabled. Estimated: ~$9/month.

**Karpenter** (`karpenter_enabled = true`): NodePool with Spot/On-Demand fallback, EC2NodeClass with gp3 encrypted EBS, SQS interruption queue. Provisioning time: 30-60s vs 3-5min (Cluster Autoscaler). Estimated: ~$0.10-0.30/hour.

## Related Projects

| Project | Description |
|---------|-------------|
| [`ai-enhanced-idp`](https://github.com/k-shevtsov/ai-enhanced-idp) | AI-Native IDP — cloud target for GitOps deployments |
| [`aiops-anomaly-detector`](https://github.com/k-shevtsov/aiops-anomaly-detector) | AIOps platform on k3s |
| [`ai-incident-response`](https://github.com/k-shevtsov/ai-incident-response) | Incident response automation |
