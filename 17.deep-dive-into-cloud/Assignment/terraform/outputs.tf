output "alb_dns_name" {
  description = "Application Load Balancer DNS endpoint"
  value       = aws_lb.main.dns_name
}

output "s3_bucket_name" {
  description = "S3 bucket for artifacts and backups"
  value       = aws_s3_bucket.app.id
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  description = "Launch Template ID"
  value       = aws_launch_template.app.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "ssh_command" {
  description = "SSH command template (replace with actual instance IP from console)"
  value       = "ssh -i ${var.key_name}.pem ec2-user@<INSTANCE_PUBLIC_IP>"
}