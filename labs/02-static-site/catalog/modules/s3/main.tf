# at `live` dir, the s3_bucket_name is defined in output
# bucket_name="$(terraform output -raw s3_bucket_name)"
# at `dist/static` dir, upload the generated images
# aws s3 sync . "s3://${bucket_name}/"
resource "aws_s3_bucket" "static_assets" {
  bucket = "${var.name}-static-assets"

  force_destroy = var.force_destroy
}
