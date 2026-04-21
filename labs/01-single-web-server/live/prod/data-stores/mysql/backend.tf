terraform {
  backend "s3" {
    # Replace this with your bucket name!
    bucket = "noidilin-tf-state"
    key    = "labs/01-single-web-server/prod/data-stores/mysql/terraform.tfstate"
    region = "ap-northeast-1"

    # Replace this with your DynamoDB table name!
    dynamodb_table = "noidilin-tf-state-locks"
    encrypt        = true
  }
}
