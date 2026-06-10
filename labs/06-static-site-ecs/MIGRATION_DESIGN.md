# Lab 06 Migration Design: EC2 Docker Runtime → ECS Express Mode

## Goal

Migrate `labs/05-static-site-ec2/` from a single public EC2 instance that runs Docker via user-data to `labs/06-static-site-ecs/`, using Amazon ECS Express Mode and Terraform `aws_ecs_express_gateway_service`.

The application artifact remains the same: a Vite-built static SPA served by Nginx from a Docker image in ECR.

## Current state: Lab 05

`labs/05-static-site-ec2/` provisions:

- ECR repository for `cidr-calculator`.
- One public EC2 instance in the default VPC.
- EC2 instance role with SSM and ECR pull permissions.
- Public HTTP security group on port 80.
- User-data that installs Docker, authenticates to ECR, pulls `${repository_url}:${image_tag}`, and starts the container.

Important limitations to retire:

- Image tag changes replace the instance and cause downtime.
- Public HTTP only; no TLS.
- No managed deployment rollback, load balancing, or service scaling.
- Runtime host lifecycle is manually modeled with EC2, systemd, Docker, and user-data.

## Target state: Lab 06

`labs/06-static-site-ecs/` should provision:

- ECR repository for the same Docker artifact.
- ECS cluster, preferably named with the lab prefix instead of relying on the default cluster.
- ECS task execution role for image pulls and CloudWatch logging.
- ECS infrastructure role for Express Mode-managed infrastructure.
- Optional application task role with no permissions by default.
- CloudWatch log group for container logs.
- `aws_ecs_express_gateway_service` running the Nginx container from ECR.
- Managed HTTPS endpoint in the form `https://<service-name>.ecs.<region>.on.aws/`.
- Express Mode scaling defaults or explicit min/max task settings.

ECS Express Mode creates and manages the underlying Fargate service, Application Load Balancer, target groups, security groups, auto scaling, monitoring, HTTPS, and deployment flow.

## Target Terraform shape

Recommended directory layout:

```text
labs/06-static-site-ecs/
├── Dockerfile                 # copy or symlink-compatible with Lab 05
├── app/                       # copy from Lab 05, or document shared artifact source
├── nginx/
├── README.md
└── infra/
    ├── modules/
    │   └── ecs-express-static-site/
    │       ├── data.tf
    │       ├── locals.tf
    │       ├── main.tf
    │       ├── outputs.tf
    │       ├── variables.tf
    │       └── versions.tf
    └── stage/
        ├── backend.hcl.example
        ├── backend.tf
        ├── locals.tf
        ├── main.tf
        ├── outputs.tf
        ├── providers.tf
        ├── stage.auto.tfvars.example
        ├── variables.tf
        └── versions.tf
```

### Core resource mapping

| Lab 05 EC2 resource | Lab 06 ECS Express replacement |
|---|---|
| `aws_instance` | `aws_ecs_express_gateway_service` |
| EC2 user-data Docker bootstrap | ECS task launch from `primary_container.image` |
| EC2 instance profile | ECS task execution role + task role |
| EC2 public HTTP security group | Express Mode-managed ALB/networking, with optional `network_configuration` |
| Public `http://<instance>` output | HTTPS Express service ingress endpoint |
| Instance replacement on tag change | ECS Express service revision/canary deployment |
| SSM instance debugging | CloudWatch logs and ECS service/task inspection |

## Minimal Terraform design

The module should keep Lab 05's explicit image tag handoff pattern.
Terraform must not build images or infer Git SHAs.

```hcl
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
  tags              = local.common_tags
}

resource "aws_ecs_cluster" "service" {
  name = "${var.name_prefix}-${var.service_name}"
  tags = local.common_tags
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
  wait_for_steady_state   = true

  primary_container {
    image          = "${aws_ecr_repository.service.repository_url}:${var.image_tag}"
    container_port = 80

    aws_logs_configuration {
      log_group         = aws_cloudwatch_log_group.service.name
      log_stream_prefix = var.service_name
    }
  }

  scaling_target {
    auto_scaling_metric       = var.auto_scaling_metric
    auto_scaling_target_value = var.auto_scaling_target_value
    min_task_count            = var.min_task_count
    max_task_count            = var.max_task_count
  }

  depends_on = [
    aws_iam_role_policy_attachment.execution,
    aws_iam_role_policy_attachment.infrastructure,
  ]

  tags = local.common_tags
}
```

## IAM design

Follow the repo lab permission rule in `docs/IAMIC-permission-for-lab.md`:

- All lab-created IAM role and policy names start with `devops-`, `lab-`, or `terraform-`.
- Every `aws_iam_role` sets `permissions_boundary = local.lab_permissions_boundary_arn`.
- Do not create or mutate `lab-devops-permissions-boundary`.

Roles:

1. **Task execution role**
   - Trust principal: `ecs-tasks.amazonaws.com`.
   - Attach: `arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy`.
   - Add scoped ECR pull permissions for the lab repository if needed. `ecr:GetAuthorizationToken` must use `Resource = "*"`.

2. **Infrastructure role**
   - Trust principal: `ecs.amazonaws.com`.
   - Attach: `arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices`.
   - This role cannot be changed in-place on the Express service; changing it forces replacement.

3. **Task role**
   - Trust principal: `ecs-tasks.amazonaws.com`.
   - No application permissions initially, because the static Nginx app calls no AWS APIs.

## Variables to carry forward

Carry forward:

- `aws_region`
- `environment`
- `project_name`
- `service_name`
- `image_tag`
- `ecr_force_delete`
- `ecr_image_tag_mutability`

Replace:

- `instance_type` → `cpu`, `memory`
- `http_ingress_cidr_blocks` → optional Express `network_configuration`, or omit for public default
- `subnet_id` → optional list `subnet_ids`, if not using default subnets

Recommended lab defaults:

```hcl
cpu                     = 256
memory                  = 512
min_task_count          = 1
max_task_count          = 3
auto_scaling_metric     = "AVERAGE_CPU"
auto_scaling_target_value = 60
health_check_path       = "/"
```

These are small enough for a lab and valid for Fargate-style task sizing.

## Outputs

Expose at least:

- `ecr_repository_name`
- `ecr_repository_url`
- `container_image`
- `docker_login_command`
- `docker_build_tag_push_commands`
- `ecs_cluster_name`
- `express_service_arn`
- `express_service_revision_arn`
- `service_url` derived from `ingress_paths`, if Terraform exposes an HTTPS endpoint entry
- `cloudwatch_log_group_name`

Keep Lab 05's image build/push UX so the learning path stays continuous.

## Migration sequence

1. **Create Lab 06 infra skeleton**
   - Copy the Dockerfile, Nginx config, and app source or document that Lab 06 reuses the Lab 05 app artifact.
   - Add the ECS Express Terraform module and stage root.

2. **Provision only shared-safe resources first**
   - Create ECR, IAM roles, log group, and cluster.
   - Do not destroy Lab 05 yet.

3. **Build and push image**
   - Build from `labs/06-static-site-ecs/` if the app is copied.
   - Push the exact tag configured as `image_tag`.

4. **Create the Express service**
   - Apply Terraform with `wait_for_steady_state = true`.
   - Verify the Express service reaches `ACTIVE`.

5. **Smoke test**
   - `curl -s -o /dev/null -w "%{http_code}" "$SERVICE_URL"`
   - Expected: `200`.
   - Browser-test the CIDR calculator and SPA fallback routing.

6. **Cut over users**
   - For the lab, document the new HTTPS Express URL.
   - If a custom domain is added later, point Route 53/CloudFront to the new target only after smoke tests pass.

7. **Retire Lab 05**
   - After the ECS path is verified, run `terraform destroy` in `labs/05-static-site-ec2/infra/stage`.
   - Set `ecr_force_delete = true` only if the old ECR repository should be removed with images.

## Rollback plan

Until Lab 05 is destroyed, rollback is simple:

- Keep the EC2 service running during validation.
- If ECS Express fails, continue using Lab 05's `service_url`.
- Re-apply Lab 05 with the last known-good `image_tag` if needed.

After Lab 05 is destroyed, rollback means redeploying the old lab from Terraform and pushing or reusing the previous image tag.

## Validation checklist

- [ ] `terraform fmt -recursive ../..`
- [ ] `terraform init -backend=false`
- [ ] `terraform validate`
- [ ] ECR image tag exists before creating/updating the Express service.
- [ ] IAM roles use the lab permissions boundary.
- [ ] Execution role can pull from ECR and write CloudWatch logs.
- [ ] Infrastructure role has `AmazonECSInfrastructureRoleforExpressGatewayServices`.
- [ ] Express service reaches steady state.
- [ ] HTTPS endpoint returns `200`.
- [ ] Browser can deep-link SPA routes without Nginx 404s.

## Intentional trade-offs for the lab

- Use ECS Express Mode instead of hand-authored ECS service + ALB to focus on migration from EC2 host management to managed container service delivery.
- Keep the app stateless and public.
- Keep ECR image tags explicit; do not use Terraform provisioners for build/push.
- Do not add a custom domain, WAF, or CloudFront until a later lab.
