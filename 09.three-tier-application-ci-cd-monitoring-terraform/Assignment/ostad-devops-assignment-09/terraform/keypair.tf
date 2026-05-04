# Generate a secure RSA key pair
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create the AWS Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-deployer-key"
  public_key = tls_private_key.ec2_key.public_key_openssh

  tags = {
    Name = "${var.project_name}-deployer-key"
  }
}

# Save private key locally (be careful with this in production)
resource "local_file" "private_key" {
  content         = tls_private_key.ec2_key.private_key_pem
  filename        = "${path.module}/${var.project_name}-deployer-key.pem"
  file_permission = "0400"
}

# Save public key locally for reference
resource "local_file" "public_key" {
  content         = tls_private_key.ec2_key.public_key_openssh
  filename        = "${path.module}/${var.project_name}-deployer-key.pub"
  file_permission = "0644"
}