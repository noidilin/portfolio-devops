data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_ecr_repository" "service" {
  name = "${var.name_prefix}-${var.service_name}"
}

data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_infrastructure_assume_role" {
  statement {
    sid     = "AllowAccessInfrastructureForECSExpressServices"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}
