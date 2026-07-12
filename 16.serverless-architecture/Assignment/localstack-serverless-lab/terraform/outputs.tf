output "s3_bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.uploads.bucket
}

output "lambda_1_name" {
  description = "Name of the S3 Event Handler Lambda"
  value       = aws_lambda_function.function1.function_name
}

output "lambda_1_arn" {
  description = "ARN of the S3 Event Handler Lambda"
  value       = aws_lambda_function.function1.arn
}

output "lambda_2_name" {
  description = "Name of the Response Formatter Lambda"
  value       = aws_lambda_function.function2.function_name
}

output "lambda_2_arn" {
  description = "ARN of the Response Formatter Lambda"
  value       = aws_lambda_function.function2.arn
}

output "localstack_endpoint" {
  description = "LocalStack gateway endpoint"
  value       = "http://localhost:4566"
}