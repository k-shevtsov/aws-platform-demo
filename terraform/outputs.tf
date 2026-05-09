output "ec2_public_ip" {
  description = "EC2 instance public IP"
  value       = module.ec2.public_ip
}

output "ec2_public_dns" {
  description = "EC2 instance public DNS"
  value       = module.ec2.public_dns
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "ssh_command" {
  description = "SSH command to connect to EC2"
  value       = "ssh -i ~/.ssh/${var.project_name}.pem ubuntu@${module.ec2.public_ip}"
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig from EC2 (uses static Elastic IP)"
  value       = "ssh -i ~/.ssh/${var.project_name}.pem ubuntu@${module.vpc.elastic_ip} 'sudo cat /etc/rancher/k3s/k3s.yaml' | sed 's/127.0.0.1/${module.vpc.elastic_ip}/'"
}

output "elastic_ip" {
  description = "Static Elastic IP (survives EC2 recreation)"
  value       = module.vpc.elastic_ip
}

output "github_actions_role_arn" {
  description = "IAM Role ARN for GitHub Actions OIDC"
  value       = module.oidc.role_arn
}

