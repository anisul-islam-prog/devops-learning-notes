output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "frontend_alb_dns" {
  description = "Frontend ALB DNS name"
  value       = aws_lb.frontend.dns_name
}

output "backend_alb_dns" {
  description = "Backend Internal ALB DNS name"
  value       = aws_lb.backend.dns_name
}

output "monitoring_server_public_ip" {
  description = "Public IP of monitoring server"
  value       = aws_instance.monitoring.public_ip
}

output "database_private_ip" {
  description = "Private IP of database server"
  value       = aws_instance.database.private_ip
}

output "key_pair_name" {
  description = "Name of the generated key pair"
  value       = aws_key_pair.deployer.key_name
}

output "s3_artifact_bucket" {
  description = "S3 bucket for deployment artifacts"
  value       = aws_s3_bucket.artifacts.id
}