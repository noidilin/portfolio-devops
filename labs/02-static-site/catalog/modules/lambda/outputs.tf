output "url" {
  description = "URL of the Lambda function"
  value       = aws_lambda_function_url.main.function_url
}

output "name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.main.arn
}
