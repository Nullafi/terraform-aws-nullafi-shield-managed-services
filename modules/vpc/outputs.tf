# ------------------------------------------------------------------------------
# VPC module – outputs
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets."
  value       = aws_subnet.public[*].cidr_block
}

output "backend_subnet_ids" {
  description = "IDs of the backend (private) subnets."
  value       = aws_subnet.backend[*].id
}

output "backend_subnet_cidrs" {
  description = "CIDR blocks of the backend subnets."
  value       = aws_subnet.backend[*].cidr_block
}

output "data_subnet_ids" {
  description = "IDs of the data (private) subnets."
  value       = aws_subnet.data[*].id
}

output "data_subnet_cidrs" {
  description = "CIDR blocks of the data subnets."
  value       = aws_subnet.data[*].cidr_block
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways."
  value       = aws_nat_gateway.main[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.main.id
}
