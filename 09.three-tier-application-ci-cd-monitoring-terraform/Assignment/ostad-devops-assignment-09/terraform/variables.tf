variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ostad-assignment-09"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for application servers"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_type" {
  description = "EC2 instance type for database"
  type        = string
  default     = "t3.micro"
}

variable "monitoring_instance_type" {
  description = "EC2 instance type for monitoring server"
  type        = string
  default     = "t3.small" # Slightly larger for PLG stack
}

variable "ami_id" {
  description = "AMI ID for launch template (will be updated after golden AMI creation)"
  type        = string
  default     = "" # Leave empty initially; will be populated after AMI baking
}

variable "github_repo" {
  description = "GitHub repository URL for CI/CD"
  type        = string
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "ostad_app_db"
}

variable "db_user" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "ostad_admin"
}

variable "db_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}
variable "github_repo_url" {
  description = "Public GitHub repo URL with frontend/ and backend/ folders"
  type        = string
}