variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name of the SSH key pair to create"
  type        = string
  default     = "devops-assignment-key"
}

variable "allowed_ssh_cidr" {
  description = "Your local IP for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "project_name" {
  description = "Project tag"
  type        = string
  default     = "assignment-11"
}