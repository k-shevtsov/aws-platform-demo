# Karpenter — Node Autoprovisioning

> **Demo note:** Karpenter requires multi-node setup and EC2 costs beyond Free Tier.
> This directory contains production-ready manifests and Terraform modules.
> Estimated cost to run: ~$0.10-0.30/hour depending on workload.

## What is Karpenter?

Karpenter is an open-source node autoprovisioner for Kubernetes, built by AWS.
Unlike Cluster Autoscaler (which scales node groups), Karpenter provisions
individual EC2 instances directly via AWS API — faster, more flexible, cheaper.

## Why Karpenter over Cluster Autoscaler?

| Feature | Cluster Autoscaler | Karpenter |
|---------|-------------------|-----------|
| Provisioning speed | 3-5 minutes | 30-60 seconds |
| Instance flexibility | Fixed node group types | Any EC2 instance type |
| Bin packing | Limited | Optimal |
| Spot instance support | Manual configuration | Native, automatic fallback |
| AWS integration | Via ASG | Direct EC2 API |

## Architecture
Pending Pod
↓
Karpenter Controller (watches for unschedulable pods)
↓
NodePool + EC2NodeClass evaluation
↓
AWS EC2 API → Launch instance (Spot or On-Demand)
↓
Node joins k3s cluster → Pod scheduled
↓
Scale-down: idle node terminated after ttlSecondsAfterEmpty

## Files

- `nodepool.yaml` — NodePool with resource limits and disruption policy
- `ec2nodeclass.yaml` — EC2NodeClass with AMI, subnet, security group config
- `terraform/` — IAM roles and SQS queue for interruption handling

## To Enable (estimated cost: ~$0.10-0.30/hour)

```bash
# 1. Apply Terraform module
cd terraform
terraform apply -var="karpenter_enabled=true"

# 2. Install Karpenter via Helm
helm install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version 1.0.0 \
  --namespace kube-system \
  --set settings.clusterName=aws-platform-demo \
  --set settings.interruptionQueue=aws-platform-demo-karpenter

# 3. Apply manifests
kubectl apply -f karpenter/nodepool.yaml
kubectl apply -f karpenter/ec2nodeclass.yaml
```
