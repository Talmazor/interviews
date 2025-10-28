output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Map of public subnet IDs"
  value       = { for k, v in aws_subnet.public : k => v.id }
}

output "private_subnet_ids" {
  description = "Map of private subnet IDs"
  value       = { for k, v in aws_subnet.private : k => v.id }
}

output "public_subnet_cidrs" {
  description = "Map of public subnet CIDR blocks"
  value       = { for k, v in aws_subnet.public : k => v.cidr_block }
}

output "private_subnet_cidrs" {
  description = "Map of private subnet CIDR blocks"
  value       = { for k, v in aws_subnet.private : k => v.cidr_block }
} 