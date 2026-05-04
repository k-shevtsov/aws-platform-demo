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
  description = "Command to get kubeconfig from EC2"
  value       = "ssh -i ~/.ssh/${var.project_name}.pem ubuntu@${module.ec2.public_ip} 'sudo cat /etc/rancher/k3s/k3s.yaml'"
}
