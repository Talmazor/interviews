output "instance_ids" {
  description = "Map of instance IDs"
  value       = { for k, v in aws_instance.instances : k => v.id }
}

output "instance_public_ips" {
  description = "Map of instance public IPs"
  value       = { for k, v in aws_instance.instances : k => v.public_ip }
}

output "instance_private_ips" {
  description = "Map of instance private IPs"
  value       = { for k, v in aws_instance.instances : k => v.private_ip }
}

output "instance_types" {
  description = "Map of instance types"
  value       = { for k, v in aws_instance.instances : k => v.instance_type }
} 