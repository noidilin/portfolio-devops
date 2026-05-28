data "aws_caller_identity" "current" {}

locals {
  iam_name_prefix              = can(regex("^(devops|lab|terraform)-", var.name)) ? var.name : "devops-${var.name}"
  lab_permissions_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/lab-devops-permissions-boundary"
}
