locals {
  common_tags = {
    Name        = var.project_name
    Environment = "Assignment"
    ManagedBy   = "Terraform"
    Owner       = "anisul-islam-fahd"
    CreatedAt   = timestamp()
  }

  # Ensure globally unique S3 bucket name
  bucket_name = lower("${var.project_name}-bucket-${random_id.suffix.hex}")
}