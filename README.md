# AWS Platform Demo

> Production-grade AWS infrastructure provisioned with Terraform: VPC, EC2, IAM, ECR, k3s — full cloud platform demo for portfolio.

[![Terraform](https://img.shields.io/badge/terraform-1.x-7B42BC.svg)](https://terraform.io)
[![AWS](https://img.shields.io/badge/AWS-eu--central--1-FF9900.svg)](https://aws.amazon.com)
[![k3s](https://img.shields.io/badge/kubernetes-k3s-326CE5.svg)](https://k3s.io)

## What This Is

A cloud platform demo that provisions production-grade AWS infrastructure from scratch using Terraform modules, deploys a Kubernetes cluster (k3s) on EC2 Free Tier, and runs a containerized application pulled from ECR.

## Architecture
Terraform (local) → AWS eu-central-1
├── VPC (10.0.0.0/16)
│   ├── Public Subnet (10.0.1.0/24)
│   ├── Internet Gateway
│   ├── Route Table
│   └── Security Group (SSH, HTTP, HTTPS, k3s API, NodePort)
├── IAM
│   ├── EC2 Role (AmazonEC2ContainerRegistryReadOnly + SSM)
│   └── Instance Profile
├── ECR (aws-platform-demo)
│   └── Lifecycle policy: keep last 10 images
└── EC2 t3.micro (Free Tier)
├── Ubuntu 24.04 LTS
├── k3s v1.35.4
└── demo-app:v1.0.0 ← pulled from ECR

## Stack

| Component | Technology | Details |
|-----------|-----------|---------|
| IaC | Terraform ~> 5.0 (AWS provider) | Modular structure |
| Network | VPC + Subnet + IGW + SG | eu-central-1a |
| Compute | EC2 t3.micro | Free Tier eligible |
| Container Runtime | k3s v1.35.4 | Lightweight Kubernetes |
| Registry | Amazon ECR | Scan on push, lifecycle policy |
| Access Management | IAM Role + Instance Profile | ECR read-only + SSM |
| State Backend | S3 + versioning | aws-platform-demo-tfstate-* |

## Quick Start

```bash
git clone https://github.com/k-shevtsov/aws-platform-demo
cd aws-platform-demo

# Prerequisites: AWS CLI, Terraform, Docker, kubectl
aws configure --profile terraform-admin

# Generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/aws-platform-demo -N ""

# Create S3 backend bucket first
aws s3 mb s3://aws-platform-demo-tfstate-<YOUR_ACCOUNT_ID> \
  --region eu-central-1 --profile terraform-admin

# Deploy
cd terraform
terraform init
terraform plan
terraform apply

# Get kubeconfig
ssh -i ~/.ssh/aws-platform-demo ubuntu@<EC2_PUBLIC_IP> \
  'sudo cat /etc/rancher/k3s/k3s.yaml' \
  | sed 's/127.0.0.1/<EC2_PUBLIC_IP>/' > ~/.kube/aws-platform-demo.yaml

kubectl --kubeconfig ~/.kube/aws-platform-demo.yaml get nodes
```

## Terraform Modules

| Module | Resources | Purpose |
|--------|-----------|---------|
| `vpc` | VPC, Subnet, IGW, Route Table, SG | Network isolation |
| `iam` | Role, Instance Profile, Policy attachments | Least-privilege access |
| `ecr` | Repository, Lifecycle policy | Container registry |
| `ec2` | Instance, Key Pair | Compute + k3s |

## Demo App

Simple Python HTTP server deployed to k3s via ECR:

```bash
curl http://<EC2_PUBLIC_IP>:30080
# {"message": "Hello from AWS!", "cluster": "k3s on EC2", "region": "eu-central-1", "version": "v1.0.0"}

curl http://<EC2_PUBLIC_IP>:30080/health
# {"status": "ok", "service": "aws-platform-demo"}
```

## Cost

All resources stay within AWS Free Tier (new accounts, 12 months):

| Resource | Free Tier | Actual Usage |
|----------|-----------|-------------|
| EC2 t3.micro | 750 hrs/month | ~720 hrs |
| S3 | 5 GB | < 1 MB |
| ECR | 500 MB | ~50 MB |
| Data transfer | 100 GB/month | minimal |

**Estimated cost: $0/month** on Free Tier.

## Cleanup

```bash
cd terraform
terraform destroy -auto-approve
```

## Related Projects

| Project | Description |
|---------|-------------|
| [`ai-enhanced-idp`](https://github.com/k-shevtsov/ai-enhanced-idp) | AI-Native IDP — this platform is the cloud backend target |
| [`aiops-anomaly-detector`](https://github.com/k-shevtsov/aiops-anomaly-detector) | AIOps platform deployed on k3s |
