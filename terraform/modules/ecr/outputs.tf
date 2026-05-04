output "repository_url" { value = aws_ecr_repository.main.repository_url }
output "registry_url"   { value = split("/", aws_ecr_repository.main.repository_url)[0] }
