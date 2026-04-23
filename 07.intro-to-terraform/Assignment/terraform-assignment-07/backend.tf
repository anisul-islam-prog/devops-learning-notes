terraform {
  backend "s3" {
    bucket       = "ostad-terraform-state-backend-unique"
    key          = "assignment-07/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}