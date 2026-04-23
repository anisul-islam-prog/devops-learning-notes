# Random suffix for globally unique S3 bucket naming
resource "random_id" "suffix" {
  byte_length = 4
}

# Fetch latest Ubuntu AMI (keeps code region-agnostic)
data "aws_ami" "ubuntu_server" {
  most_recent = true
  # ownerid
  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Login to ec2 with .pem
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/Projects/devops-learning-notes/anisul-islam-fahd.pub")
}

# Default VPC data source
data "aws_vpc" "default" {
  default = true
}

# Security Group for SSH and basic egress
resource "aws_security_group" "instance" {
  name_prefix = "${var.project_name}-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from MyIP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["161.248.241.230/32"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sg"
  })
}

# EC2 Instance
resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu_server.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.instance.id]

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-EC2"
  })
}

# S3 Bucket
resource "aws_s3_bucket" "artifacts" {
  bucket = local.bucket_name

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-S3"
  })
}

# S3 Bucket Ownership Controls (AWS Provider v5 best practice)
resource "aws_s3_bucket_ownership_controls" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Block all public access (security best practice)
resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}