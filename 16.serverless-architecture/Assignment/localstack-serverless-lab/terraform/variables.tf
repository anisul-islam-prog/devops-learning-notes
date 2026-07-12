variable "bucket_name" {
  description = "Name of the S3 bucket for uploads"
  type        = string
  default     = "user-uploads-bucket"
}

variable "lambda_1_name" {
  description = "Name of the S3 event handler Lambda"
  type        = string
  default     = "s3-event-handler"
}

variable "lambda_2_name" {
  description = "Name of the response formatter Lambda"
  type        = string
  default     = "response-formatter"
}