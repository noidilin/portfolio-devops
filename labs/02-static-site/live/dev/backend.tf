terraform {
  backend "s3" {
    bucket = "noidilin-tf-state"
    key    = "labs/02-static-site/live/dev/terraform.tfstate"
    region = "ap-northeast-1"

    dynamodb_table = "noidilin-tf-state-locks"
    encrypt        = true
  }
}
