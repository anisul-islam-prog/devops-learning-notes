provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Ostad-DevOps-Assignment-09"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "anisul-islam-fahd"
    }
  }
}