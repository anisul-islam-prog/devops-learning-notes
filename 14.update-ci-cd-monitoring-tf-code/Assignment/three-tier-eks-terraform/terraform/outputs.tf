output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "frontend_sg_id" {
  description = "Frontend security group ID"
  value       = aws_security_group.frontend.id
}

output "backend_sg_id" {
  description = "Backend security group ID"
  value       = aws_security_group.backend.id
}

output "database_sg_id" {
  description = "Database security group ID"
  value       = aws_security_group.database.id
}

output "eksctl_command" {
  description = "Command to create EKS cluster with eksctl using this VPC"
  value       = "eksctl create cluster -f eksctl-cluster.yaml"
}