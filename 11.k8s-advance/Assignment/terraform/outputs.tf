output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_eip.k8s_eip.public_ip
}

output "ec2_instance_id" {
  description = "Instance ID"
  value       = aws_instance.k8s_node.id
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_eip.k8s_eip.public_ip}"
}

output "private_key_path" {
  description = "Path to the generated private key"
  value       = local_file.private_key.filename
}