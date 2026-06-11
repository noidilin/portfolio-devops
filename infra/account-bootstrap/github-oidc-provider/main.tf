resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = []

  tags = var.tags

  lifecycle {
    ignore_changes = [
      tags,
      tags_all,
      thumbprint_list,
    ]
  }
}
