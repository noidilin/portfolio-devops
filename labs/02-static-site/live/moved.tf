moved {
  from = aws_dynamodb_table.asset_metadata
  to   = module.ddb.aws_dynamodb_table.asset_metadata
}

moved {
  from = aws_s3_bucket.static_assets
  to   = module.s3.aws_s3_bucket.static_assets
}
