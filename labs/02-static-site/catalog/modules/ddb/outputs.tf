output "name" {
  description = "Name of the DynamoDB table for asset metadata"
  value       = aws_dynamodb_table.asset_metadata.name
}

output "arn" {
  description = "ARN of the DynamoDB table for asset metadata"
  value       = aws_dynamodb_table.asset_metadata.arn
}

