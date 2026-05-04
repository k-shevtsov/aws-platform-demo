variable "project_name"      { type = string }
variable "environment"       { type = string }
variable "subnet_id"         { type = string }
variable "security_group_id" { type = string }
variable "instance_type"     { type = string }
variable "instance_profile"  { type = string }
variable "ssh_allowed_cidr"  { type = string }
variable "ecr_registry_url"  { type = string }
variable "aws_region" {
  type    = string
  default = "eu-central-1"
}
variable "elastic_ip_id" {
  description = "Elastic IP allocation ID"
  type        = string
}
variable "elastic_ip" {
  description = "Elastic IP address for TLS SAN"
  type        = string
}
