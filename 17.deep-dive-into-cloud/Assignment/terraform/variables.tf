variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "owner_email" {
  description = "Your email for tagging"
  type        = string
}

variable "key_name" {
  description = "Existing EC2 Key Pair name for emergency SSH access"
  type        = string
}

variable "my_ip" {
  description = "Your public IP for SSH access (e.g., 203.0.113.10/32)"
  type        = string
}

variable "instance_profile_name" {
  description = "Name of EXISTING IAM Instance Profile for EC2. You cannot create IAM resources, so use an existing one or request from admin."
  type        = string
  default     = "" # Leave empty if none exists; app will work without S3/CloudWatch integration
}

variable "app_repo_url" {
  description = "GitHub repository URL"
  type        = string
  default     = "https://github.com/roy35-909/Module-3-deployment.git"
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 3000
}