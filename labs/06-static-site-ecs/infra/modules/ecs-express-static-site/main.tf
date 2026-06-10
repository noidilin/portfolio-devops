resource "aws_ecr_repository" "service" {
  name                 = "${var.name_prefix}-${var.service_name}"
  image_tag_mutability = var.ecr_image_tag_mutability
  force_delete         = var.ecr_force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "service" {
  name              = "/ecs/express/${var.name_prefix}-${var.service_name}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

resource "aws_ecs_cluster" "service" {
  name = "${var.name_prefix}-${var.service_name}"

  tags = local.common_tags
}

resource "aws_iam_role" "execution" {
  name                 = "${var.name_prefix}-${var.service_name}-ecs-execution"
  permissions_boundary = local.lab_permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name                 = "${var.name_prefix}-${var.service_name}-ecs-task"
  permissions_boundary = local.lab_permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role" "infrastructure" {
  name                 = "${var.name_prefix}-${var.service_name}-ecs-infra"
  permissions_boundary = local.lab_permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.ecs_infrastructure_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "infrastructure" {
  role       = aws_iam_role.infrastructure.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices"
}

# ECS Express currently retries scaling target creation if the AWS managed
# infrastructure policy's tag condition does not match the Application Auto
# Scaling target during initial provisioning. Keep this supplemental allow scoped
# to ECS scalable targets only, while the lab permissions boundary still blocks
# IAM/Organizations/Account mutation from this service role.
resource "aws_iam_role_policy" "infrastructure_application_autoscaling" {
  name = "${var.name_prefix}-${var.service_name}-ecs-infra-app-autoscaling"
  role = aws_iam_role.infrastructure.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEcsExpressApplicationAutoScaling"
        Effect = "Allow"
        Action = [
          "application-autoscaling:RegisterScalableTarget",
          "application-autoscaling:DeregisterScalableTarget",
          "application-autoscaling:PutScalingPolicy",
          "application-autoscaling:DeleteScalingPolicy",
          "application-autoscaling:DescribeScalableTargets",
          "application-autoscaling:DescribeScalingPolicies",
          "application-autoscaling:DescribeScalingActivities",
          "application-autoscaling:TagResource"
        ]
        Resource = "arn:aws:application-autoscaling:*:*:scalable-target/*"
        Condition = {
          StringEquals = {
            "application-autoscaling:service-namespace" = "ecs"
          }
        }
      }
    ]
  })
}

resource "aws_ecs_express_gateway_service" "service" {
  service_name            = "${var.name_prefix}-${var.service_name}"
  cluster                 = aws_ecs_cluster.service.name
  execution_role_arn      = aws_iam_role.execution.arn
  infrastructure_role_arn = aws_iam_role.infrastructure.arn
  task_role_arn           = aws_iam_role.task.arn
  cpu                     = var.cpu
  memory                  = var.memory
  health_check_path       = var.health_check_path
  wait_for_steady_state   = var.wait_for_steady_state

  primary_container {
    image          = local.container_image
    container_port = var.container_port

    aws_logs_configuration {
      log_group         = aws_cloudwatch_log_group.service.name
      log_stream_prefix = var.service_name
    }
  }

  dynamic "network_configuration" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []

    content {
      subnets         = var.subnet_ids
      security_groups = var.security_group_ids
    }
  }

  scaling_target {
    auto_scaling_metric       = var.auto_scaling_metric
    auto_scaling_target_value = var.auto_scaling_target_value
    min_task_count            = var.min_task_count
    max_task_count            = var.max_task_count
  }

  lifecycle {
    precondition {
      condition = (
        (var.cpu == "256" && contains(["512", "1024", "2048"], var.memory)) ||
        (var.cpu == "512" && contains(["1024", "2048", "3072", "4096"], var.memory)) ||
        (var.cpu == "1024" && contains(["2048", "3072", "4096", "5120", "6144", "7168", "8192"], var.memory)) ||
        (var.cpu == "2048" && contains(["4096", "5120", "6144", "7168", "8192"], var.memory)) ||
        (var.cpu == "4096" && contains(["8192"], var.memory))
      )
      error_message = "cpu and memory must be a valid Fargate task size combination."
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.execution,
    aws_iam_role_policy_attachment.infrastructure,
    aws_iam_role_policy.infrastructure_application_autoscaling,
    aws_cloudwatch_log_group.service,
  ]

  tags = local.common_tags
}
