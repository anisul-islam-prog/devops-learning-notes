variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "Ubuntu 24.04 LTS AMI ID for your region"
  type        = string
  default     = "ami-0f8a61b66d1accaee" # Ubuntu 24.04 us-east-1; verify in console
}

variable "key_pair_name" {
  description = "Existing EC2 Key Pair name for SSH"
  type        = string
}

variable "artifact_bucket_name" {
  description = "Globally unique S3 bucket name for artifacts"
  type        = string
}