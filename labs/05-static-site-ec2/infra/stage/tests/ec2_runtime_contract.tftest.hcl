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

  mock_data "aws_vpc" {
    defaults = {
      id = "vpc-1234567890abcdef0"
    }
  }

  mock_data "aws_subnets" {
    defaults = {
      ids = ["subnet-1234567890abcdef0"]
    }
  }

  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-1234567890abcdef0"
    }
  }

  mock_data "aws_ecr_repository" {
    defaults = {
      name           = "devops-static-site-ec2-stage-cidr-calculator"
      arn            = "arn:aws:ecr:ap-northeast-1:123456789012:repository/devops-static-site-ec2-stage-cidr-calculator"
      repository_url = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/devops-static-site-ec2-stage-cidr-calculator"
    }
  }
}

override_data {
  target = module.runtime.data.aws_iam_policy_document.ec2_assume_role
  values = {
    json = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }]
    })
  }
}

override_data {
  target = module.runtime.data.aws_iam_policy_document.ecr_pull
  values = {
    json = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Action   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
        Effect   = "Allow"
        Resource = "arn:aws:ecr:ap-northeast-1:123456789012:repository/devops-static-site-ec2-stage-cidr-calculator"
      }]
    })
  }
}

override_resource {
  target          = module.runtime.aws_instance.service
  override_during = plan
  values = {
    id         = "i-1234567890abcdef0"
    public_dns = "ec2-203-0-113-10.ap-northeast-1.compute.amazonaws.com"
    public_ip  = "203.0.113.10"
  }
}

override_resource {
  target          = module.runtime.aws_security_group.instance
  override_during = plan
  values = {
    id = "sg-1234567890abcdef0"
  }
}

run "lab05_ec2_runtime_contract" {
  command = plan

  variables {
    image_tag = "sha-0123456789abcdef0123456789abcdef01234567"
  }

  assert {
    condition     = output.container_image == "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/devops-static-site-ec2-stage-cidr-calculator:sha-0123456789abcdef0123456789abcdef01234567"
    error_message = "Stage must construct the EC2 container image from the durable ECR repository and an explicit image tag."
  }

  assert {
    condition     = output.instance_type == "t3.micro" && output.root_volume_size_gb == 20 && output.root_volume_type == "gp3" && output.root_volume_encrypted == true
    error_message = "Lab 05 EC2 runtime should default to a lab-sized t3.micro instance with a small encrypted gp3 root volume."
  }

  assert {
    condition     = output.container_port == 80
    error_message = "The EC2 runtime should expose only the shared static-site HTTP port 80 through its learner-facing ingress rule."
  }

  assert {
    condition     = output.ssh_ingress_enabled == false
    error_message = "The EC2 runtime should use SSM inspection and keep SSH ingress out of the learner contract."
  }

  assert {
    condition     = can(regex("aws ssm start-session --region ap-northeast-1 --target .+", output.ssm_start_session_command))
    error_message = "Runtime outputs should include an AWS SSM Session Manager command for instance inspection."
  }

  assert {
    condition     = can(regex("^http://", output.service_url)) && output.instance_id == "i-1234567890abcdef0" && output.security_group_id == "sg-1234567890abcdef0" && output.ecr_repository_name == "devops-static-site-ec2-stage-cidr-calculator"
    error_message = "Runtime outputs should expose the service endpoint, EC2 instance, security group, and durable ECR repository for CI and learner inspection."
  }
}
