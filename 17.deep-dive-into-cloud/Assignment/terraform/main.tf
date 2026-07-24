terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # S3 backend for state storage (no DynamoDB = no locking, fine for solo work)
  backend "s3" {
    bucket  = "ostad-tfstate-738928894806" # Use YOUR account ID for global uniqueness
    key     = "assignment-17/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Ostad-Assignment-17"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner_email
    }
  }
}