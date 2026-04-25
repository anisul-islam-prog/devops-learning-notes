variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile"
  type        = string
}

variable "project_name" {
  description = "Project identifier for resource naming"
  type        = string
  default     = "Assignment08VPC"
}

variable "my_ip" {
  description = "Your public IP address with CIDR"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}