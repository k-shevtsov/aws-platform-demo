output "vpc_id"            { value = aws_vpc.main.id }
output "public_subnet_id"  { value = aws_subnet.public.id }
output "security_group_id" { value = aws_security_group.main.id }
output "elastic_ip"            { value = aws_eip.main.public_ip }
output "elastic_ip_id"         { value = aws_eip.main.id }
