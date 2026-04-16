resource "aws_lambda_function" "main" {
  function_name = "${var.name}-function"

  # the ZIP is produced by `app/best-cat/package.json`
  # where lambda function get the handler
  filename         = var.lambda_zip_file
  source_code_hash = filebase64sha256(var.lambda_zip_file)

  role = module.iam.arn

  # lambda looks inside the ZIP for `index.js` and the function named `handler`
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size
  architectures = var.lambda_architectures

  environment {
    variables = {
      S3_BUCKET_NAME      = module.s3.name
      DYNAMODB_TABLE_NAME = module.ddb.name
    }
  }

  # depends_on = [
  #   aws_iam_role_policy_attachment.lambda_s3_read,
  #   aws_iam_role_policy_attachment.lambda_dynamodb,
  #   aws_iam_role_policy_attachment.lambda_basic_execution
  # ]
}

resource "aws_lambda_function_url" "main" {
  function_name      = aws_lambda_function.main.function_name
  authorization_type = "NONE"
}
