# Latest Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# SSH Key Pair
resource "aws_key_pair" "main" {
  key_name   = var.project_name
  public_key = var.ssh_public_key

  tags = {
    Name      = var.project_name
    ManagedBy = "terraform"
  }
}

# EC2 Instance
resource "aws_instance" "main" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.instance_profile
  key_name               = aws_key_pair.main.key_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    ecr_registry_url = var.ecr_registry_url
    aws_region       = var.aws_region
    project_name     = var.project_name
    elastic_ip       = var.elastic_ip
  }))

  tags = {
    Name        = "${var.project_name}-k3s"
    Environment = var.environment
    ManagedBy   = "terraform"
    Role        = "k3s-server"
  }
}

# Associate Elastic IP with EC2
resource "aws_eip_association" "main" {
  instance_id   = aws_instance.main.id
  allocation_id = var.elastic_ip_id
}
