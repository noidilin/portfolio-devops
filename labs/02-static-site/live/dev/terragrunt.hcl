include "root" {
  path = find_in_parent_folders("root.hcl")
}

# HACK: Those // before `best_cat` are there on purpose.
# They’re how go-getter, the library that Terragrunt uses,
# indicates that it’s working with a directory within a module source.
# This allows relative references like ../s3 to work within the best_cat module.
terraform {
    source = "../../catalog/modules//best_cat"
}

inputs = {
  name = "break-terralith-dev"
  lambda_zip_file = "${get_repo_root()}/labs/02-static-site/dist/best-cat.zip"
  aws_region = "ap-northeast-1"
}
