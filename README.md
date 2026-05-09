# AWS Platform Demo

> Production-grade AWS infrastructure provisioned with Terraform: VPC, EC2, IAM, ECR, k3s, CloudWatch, Secrets Manager, ESO, Atlantis, CloudTrail, AWS Config — full cloud platform demo for portfolio.

[![Terraform](https://img.shields.io/badge/terraform-1.x-7B42BC.svg)](https://terraform.io)
[![AWS](https://img.shields.io/badge/AWS-eu--central--1-FF9900.svg)](https://aws.amazon.com)
[![k3s](https://img.shields.io/badge/kubernetes-k3s-326CE5.svg)](https://k3s.io)
[![OIDC](https://img.shields.io/badge/auth-OIDC-green.svg)](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
[![Atlantis](https://img.shields.io/badge/GitOps-Atlantis-1A73E8.svg)](https://www.runatlantis.io)

## What This Is

A cloud platform demo that provisions production-grade AWS infrastructure from scratch using Terraform modules, deploys k3s on EC2, and integrates a full observability, secrets management, compliance, and GitOps stack — all without long-lived AWS credentials.

## Architecture
Terraform (local/CI) → AWS eu-central-1
├── VPC (10.0.0.0/16)
│   ├── Public Subnet (10.0.1.0/24)
│   ├── Internet Gateway + Route Table
│   ├── Security Group (SSH backup, HTTP, HTTPS, k3s API, NodePort)
│   └── Elastic IP (static, survives EC2 recreation)
├── IAM
│   ├── EC2 Role (ECR + SSM + CloudWatch + Secrets Manager)
│   ├── Instance Profile
│   └── GitHub Actions OIDC Role (AdministratorAccess, zero long-lived credentials)
├── ECR (aws-platform-demo)
│   └── Lifecycle policy: keep last 10 images, scan on push
├── S3 (Terraform state)
│   └── DynamoDB (state locking + encryption, prevent_destroy)
├── Secrets Manager
│   ├── aws-platform-demo/demo-app/config
│   └── aws-platform-demo/atlantis/secrets
├── CloudTrail
│   └── S3 bucket (90-day retention)
├── AWS Config (6 CIS Benchmark rules)
│   ├── no-unrestricted-ssh, s3-no-public-access
│   ├── ebs-encrypted, iam-no-root-access-key
│   ├── mfa-enabled-root, cloudtrail-enabled
└── EC2 t3.small
├── Ubuntu 24.04 LTS + 2GB swap
├── k3s v1.35.4 (TLS SAN for stable kubeconfig)
├── demo-app:v1.0.0 ← pulled from ECR
├── Fluent Bit DaemonSet → CloudWatch Logs
├── External Secrets Operator → Secrets Manager
└── Atlantis → GitHub PR automation

## Stack

| Component | Technology | Details |
|-----------|-----------|---------|
| IaC | Terraform ~> 5.0 | Modular: vpc, ec2, iam, ecr, oidc, config, cloudtrail, karpenter |
| Network | VPC + Subnet + IGW + SG + Elastic IP | eu-central-1a, static IP |
| Compute | EC2 t3.small | 2GB RAM, Ubuntu 24.04, gp3 encrypted EBS |
| Container Runtime | k3s v1.35.4 | TLS SAN, kubeconfig stable across restarts |
| Registry | Amazon ECR | Scan on push, lifecycle policy |
| State Backend | S3 + DynamoDB | Versioning + locking + encryption + prevent_destroy |
| CI Auth | GitHub Actions OIDC | Zero long-lived AWS credentials, 2h session |
| Secrets | AWS Secrets Manager + ESO | SecretSynced: True, auto-refresh 1h |
| Observability | Fluent Bit + CloudWatch Logs | Structured JSON with k8s metadata, 7d retention |
| Audit | CloudTrail | Full AWS API audit log, S3 delivery |
| Compliance | AWS Config | 6 CIS Benchmark rules, continuous monitoring |
| GitOps | Atlantis v0.35.0 | terraform plan/apply via PR comments |
| Autoscaling | Karpenter manifests | NodePool + EC2NodeClass, production-ready stub |
| Cost Control | EC2 stop/start schedule | 22:00 UTC stop, 07:00 UTC start Mon-Fri |

## Security Highlights

**Zero long-lived credentials** — GitHub Actions authenticates via OIDC:
GitHub Actions → sts:AssumeRoleWithWebIdentity → temporary credentials (2h)

No `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` in GitHub Secrets.

**Secrets never hardcoded** — AWS Secrets Manager + External Secrets Operator:
AWS Secrets Manager → ESO ClusterSecretStore → Kubernetes Secret (auto-sync 1h)

**GitOps for infrastructure** — Atlantis automates Terraform via PR:
PR opened → Atlantis webhook → terraform plan → PR comment
PR comment "atlantis apply" → terraform apply → infrastructure updated

## Quick Start

```bash
git clone https://github.com/k-shevtsov/aws-platform-demo
cd aws-platform-demo

# Prerequisites: AWS CLI, Terraform >= 1.0, kubectl, helm, gh

# 1. Configure AWS
aws configure --profile terraform-admin

# 2. Generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/aws-platform-demo -N ""

# 3. Create S3 backend bucket + DynamoDB
aws s3 mb s3://aws-platform-demo-tfstate-<ACCOUNT_ID> \
  --region eu-central-1 --profile terraform-admin

aws dynamodb create-table \
  --table-name aws-platform-demo-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1 --profile terraform-admin

# 4. Deploy infrastructure
cd terraform
terraform init
terraform apply -var="ssh_public_key=$(cat ~/.ssh/aws-platform-demo.pub)"

# 5. Get kubeconfig
ssh -i ~/.ssh/aws-platform-demo ubuntu@<ELASTIC_IP> \
  'sudo cat /etc/rancher/k3s/k3s.yaml' \
  | sed 's/127.0.0.1/<ELASTIC_IP>/' > ~/.kube/aws-platform-demo.yaml

# 6. Restore Kubernetes workloads
bash scripts/restore-k8s.sh
```

## CI/CD Workflows

| Workflow | Trigger | Action |
|----------|---------|--------|
| `terraform-plan.yml` | push/PR to `terraform/**` | init + validate + plan + PR comment |
| `terraform-scheduled.yml` | 22:00 UTC daily | EC2 stop (cost saving) |
| `terraform-scheduled.yml` | 07:00 UTC Mon-Fri | EC2 start |
| `terraform-scheduled.yml` | `workflow_dispatch` | manual start/stop/apply/destroy |

## Terraform Modules

| Module | Resources | Status |
|--------|-----------|--------|
| `vpc` | VPC, Subnet, IGW, Route Table, SG, Elastic IP | ✅ Active |
| `iam` | EC2 Role, Instance Profile, CloudWatch + Secrets policies | ✅ Active |
| `ecr` | Repository, Lifecycle policy | ✅ Active |
| `ec2` | Instance (t3.small), Key Pair, EIP association | ✅ Active |
| `oidc` | OIDC Provider, GitHub Actions IAM Role | ✅ Active |
| `cloudtrail` | Trail, S3 bucket, 90-day retention | ✅ Active |
| `config` | 6 CIS Config rules, recorder, delivery channel | ✅ Active |
| `karpenter` | Controller IAM Role, SQS interruption queue | ⚙️ Stub (EC2 costs) |

## Kubernetes Stack
NAMESPACE          NAME                      READY   PURPOSE
default            demo-app-*                1/1     ECR image → NodePort 30080
logging            fluent-bit-*              1/1     Pod logs → CloudWatch
external-secrets   external-secrets-*        1/1     Secrets Manager → k8s Secret
atlantis           atlantis-*                1/1     Terraform GitOps via PR

## Restore After EC2 Stop/Start

```bash
# Full automated restore (reads Atlantis secrets from Secrets Manager)
bash scripts/restore-k8s.sh
```

## Cost

| Resource | Details | Monthly |
|----------|---------|---------|
| EC2 t3.small | Stop 22:00-07:00 UTC, ~9h/day × 5d/week | ~$3.50 |
| S3 state | Versioning enabled | ~$0.10 |
| ECR | Image storage | ~$0.10 |
| CloudWatch Logs | 7d retention | ~$0.50 |
| Secrets Manager | 2 secrets | ~$0.80 |
| CloudTrail | S3 delivery | ~$2.00 |
| AWS Config | 6 rules | ~$9.00 |
| DynamoDB | PAY_PER_REQUEST | ~$0.10 |
| Elastic IP | Attached to running instance | $0 |
| **Total** | | **~$16/month** |

> Covered by AWS credits ($140 available).

## Karpenter — Production-Ready Manifests

NodePool with Spot/On-Demand fallback and 30s consolidation policy:

```bash
# Enable when multi-node setup available
kubectl apply -f karpenter/nodepool.yaml
kubectl apply -f karpenter/ec2nodeclass.yaml
```

See `karpenter/README.md` for full enablement guide and cost estimates.

## Related Projects

| Project | Description |
|---------|-------------|
| [`ai-enhanced-idp`](https://github.com/k-shevtsov/ai-enhanced-idp) | AI-Native IDP — Claude validation agent + ArgoCD GitOps |
| [`aiops-anomaly-detector`](https://github.com/k-shevtsov/aiops-anomaly-detector) | AIOps platform — anomaly detection + self-healing |
| [`ai-incident-response`](https://github.com/k-shevtsov/ai-incident-response) | Incident response automation with Claude |
| [`mini-idp`](https://github.com/k-shevtsov/mini-idp) | Predecessor IDP — Port.io + kind + kubectl apply |
