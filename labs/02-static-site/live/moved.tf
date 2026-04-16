moved {
  from = aws_dynamodb_table.asset_metadata
  to   = module.ddb.aws_dynamodb_table.asset_metadata
}
