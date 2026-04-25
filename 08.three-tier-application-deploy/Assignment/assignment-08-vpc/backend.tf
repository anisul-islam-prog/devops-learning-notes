terraform {
  backend "s3" {
    bucket       = "terraform-state-backend-assignment-08"
    key          = "assignment-08/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}