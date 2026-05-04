variable "project_name" { type = string }
variable "environment"  { type = string }
variable "vpc_cidr"     { type = string }
variable "public_subnet_cidr" { type = string }
variable "aws_region"   { type = string }
variable "ssh_allowed_cidr" {
  type    = string
  default = "0.0.0.0/0"
}
