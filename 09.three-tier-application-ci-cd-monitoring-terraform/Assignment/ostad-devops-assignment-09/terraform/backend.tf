terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }

  backend "s3" {
    bucket  = "terraform-state-bucket-state-backend-assignment-09" # Create this S3 bucket first manually
    key     = "assignment-09/terraform.tfstate"
    region  = "us-east-1" # Change to your region
    encrypt = true
    # If you don't have DynamoDB, omit this or use a local lock file for the assignment
    # dynamodb_table = "terraform-locks"
  }
}