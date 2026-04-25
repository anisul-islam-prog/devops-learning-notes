locals {
  common_tags = {
    Environment = "Assignment"
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
  name_prefix = var.project_name
}