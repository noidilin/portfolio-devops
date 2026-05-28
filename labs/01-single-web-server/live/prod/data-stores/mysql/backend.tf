terraform {
  backend "s3" {
    # Replace this with your bucket name!
    bucket       = "noidilin-tf-state"
    key          = "labs/01-single-web-server/live/prod/data-stores/mysql/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
