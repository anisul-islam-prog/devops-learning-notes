variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of AWS EC2 Key Pair"
  type        = string
  # Set this to your existing key pair name
}

variable "my_ip" {
  description = "Your public IP for SSH access (CIDR notation, e.g., 203.0.113.0/32)"
  type        = string
}