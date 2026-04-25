output "vpc_id" {
  description = "Created VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public Subnet ID"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "Private Subnet ID"
  value       = aws_subnet.private.id
}

output "bastion_public_ip" {
  description = "Bastion host public IP"
  value       = aws_instance.bastion.public_ip
}

output "public_ec2_public_ip" {
  description = "Public EC2 public IP"
  value       = aws_instance.public.public_ip
}

output "private_ec2_private_ip" {
  description = "Private EC2 private IP"
  value       = aws_instance.private.private_ip
}

output "ssh_private_key_path" {
  description = "Path to generated SSH private key"
  value       = local_file.private_key_pem.filename
}

output "ssh_bastion_command" {
  description = "SSH command for bastion access"
  value       = "ssh -i ${local_file.private_key_pem.filename} ubuntu@${aws_instance.bastion.public_ip}"
}

output "ssh_private_via_bastion_command" {
  description = "SSH command for private instance via bastion"
  value       = "ssh -i ${local_file.private_key_pem.filename} -o IdentitiesOnly=yes -o ProxyCommand='ssh -i ${local_file.private_key_pem.filename} -W %h:%p ubuntu@${aws_instance.bastion.public_ip}' ubuntu@${aws_instance.private.private_ip}"
}

output "http_test_url" {
  description = "URL to test public HTTP access"
  value       = "http://${aws_instance.public.public_ip}"
}