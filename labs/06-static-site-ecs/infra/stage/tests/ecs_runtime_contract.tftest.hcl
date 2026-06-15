mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "ap-northeast-1"
    }
  }

  mock_data "aws_ecr_repository" {
    defaults = {
      name           = "devops-static-site-ecs-stage-cidr-calculator"
      arn            = "arn:aws:ecr:ap-northeast-1:123456789012:repository/devops-static-site-ecs-stage-cidr-calculator"
      repository_url = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/devops-static-site-ecs-stage-cidr-calculator"
    }
  }
}

override_data {
  target = module.runtime.data.aws_iam_policy_document.ecs_tasks_assume_role
  values = {
    json = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }]
    })
  }
}

override_data {
  target = module.runtime.data.aws_iam_policy_document.ecs_infrastructure_assume_role
  values = {
    json = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid    = "AllowAccessInfrastructureForECSExpressServices"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
      }]
    })
  }
}

override_resource {
  target          = module.runtime.aws_ecs_cluster.service
  override_during = plan
  values = {
    arn = "arn:aws:ecs:ap-northeast-1:123456789012:cluster/devops-static-site-ecs-stage-cidr-calculator"
  }
}

override_resource {
  target          = module.runtime.aws_ecs_express_gateway_service.service
  override_during = plan
  values = {
    service_arn          = "arn:aws:ecs:ap-northeast-1:123456789012:express-gateway-service/devops-static-site-ecs-stage-cidr-calculator"
    service_revision_arn = "arn:aws:ecs:ap-northeast-1:123456789012:express-gateway-service/devops-static-site-ecs-stage-cidr-calculator/revision/1"
    ingress_paths = [{
      endpoint = "https://example.execute-api.ap-northeast-1.amazonaws.com/"
      path     = "/"
    }]
  }
}

run "lab06_ecs_runtime_contract" {
  command = plan

  variables {
    image_tag = "sha-0123456789abcdef0123456789abcdef01234567"
  }

  assert {
    condition     = output.container_image == "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/devops-static-site-ecs-stage-cidr-calculator:sha-0123456789abcdef0123456789abcdef01234567"
    error_message = "Stage must construct the ECS container image from the durable ECR repository and an explicit image tag."
  }

  assert {
    condition     = output.cpu == "256" && output.memory == "512" && output.min_task_count == 1 && output.max_task_count == 3 && output.auto_scaling_metric == "AVERAGE_CPU" && output.auto_scaling_target_value == 60
    error_message = "Lab 06 ECS Express runtime should default to lab-sized CPU, memory, task count, and autoscaling settings."
  }

  assert {
    condition     = output.health_check_path == "/" && output.container_port == 80
    error_message = "The ECS runtime should expose the shared static-site HTTP port 80 and use the root health check path."
  }

  assert {
    condition     = output.log_retention_days == 14 && output.cloudwatch_log_group_name == "/ecs/express/devops-static-site-ecs-stage-cidr-calculator"
    error_message = "The ECS runtime should keep lab-sized CloudWatch log retention and expose the log group name."
  }

  assert {
    condition     = output.wait_for_steady_state == true
    error_message = "Terraform should wait for ECS Express steady state before completing runtime apply."
  }

  assert {
    condition     = output.ecr_repository_name == "devops-static-site-ecs-stage-cidr-calculator" && output.ecs_cluster_name == "devops-static-site-ecs-stage-cidr-calculator" && output.express_service_name == "devops-static-site-ecs-stage-cidr-calculator" && output.express_service_arn == "arn:aws:ecs:ap-northeast-1:123456789012:express-gateway-service/devops-static-site-ecs-stage-cidr-calculator" && output.express_service_revision_arn == "arn:aws:ecs:ap-northeast-1:123456789012:express-gateway-service/devops-static-site-ecs-stage-cidr-calculator/revision/1" && output.service_url == "https://example.execute-api.ap-northeast-1.amazonaws.com/"
    error_message = "Runtime outputs should expose the durable repository, ECS cluster/service identity, current revision, and service endpoint for CI and learner inspection."
  }

  assert {
    condition     = can(regex("aws ecs describe-express-gateway-service --region ap-northeast-1 --service-arn .+", output.describe_express_service_command)) && can(regex("aws ecs monitor-express-gateway-service --region ap-northeast-1 --service-arn .+", output.monitor_express_service_command))
    error_message = "Runtime outputs should include ECS Express describe and monitor commands for learner inspection."
  }
}
