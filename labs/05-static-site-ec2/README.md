# Lab 05: Static Site on EC2

Terraform tracer bullet for a single EC2-hosted Docker service runtime path.

## Infrastructure

- Reusable module: `infra/modules/ec2-docker-runtime`
- Stage root: `infra/stage`

The stage root provisions:

- an ECR repository for the `cidr-calculator` image artifact
- one public EC2 instance in the default VPC/subnets
- an IAM instance profile for SSM Session Manager and ECR image pulls
- a security group with public HTTP ingress on port 80, no SSH ingress, and outbound access
- outputs for image push commands, HTTP access, and SSM inspection

## Backend and variables pattern

This lab uses the `backend.hcl` pattern for backend settings and `.auto.tfvars` for normal Terraform input variables.

Backend config is loaded by `terraform init`, so it cannot come from `.auto.tfvars`.

```sh
cd infra/stage
cp backend.hcl.example backend.hcl
cp stage.auto.tfvars.example stage.auto.tfvars
terraform init -backend-config=backend.hcl
```

For local syntax validation without remote state:

```sh
cd infra/stage
terraform init -backend=false
terraform validate
```

## Test commands

Preview changes:

```sh
cd infra/stage
terraform fmt -recursive ../..
terraform validate
terraform plan
```

Create infrastructure:

```sh
terraform apply
```

Inspect useful commands/URLs:

```sh
terraform output
```

## Deploy a pushed image tag

Build and push the image separately; Terraform only consumes the explicit tag.
The configured `image_tag` is rendered into EC2 user-data, so changing it replaces
the instance and reruns bootstrap deterministically.

```sh
cd infra/stage
terraform output docker_login_command
terraform output docker_build_tag_push_commands
```

After running those commands from the lab root, set `image_tag` in
`infra/stage/stage.auto.tfvars` to the pushed tag and apply:

```sh
terraform apply
```

### CI-built image tag limitation

If a CI/CD system such as GitHub Actions builds and pushes the image, Terraform
will not automatically know the Git commit SHA used as the image tag unless that
same value is passed into Terraform.

For example, if GitHub Actions pushes:

```text
cidr-calculator:${GITHUB_SHA}
```

then a Terraform run outside that pipeline must receive the same tag explicitly:

```sh
terraform apply -var="image_tag=<github-sha>"
```

Terraform should not try to derive the tag by running `git rev-parse HEAD`: the
local checkout may not match the commit that CI built, and the resulting plan
would depend on the machine running Terraform rather than the deployed artifact.

If CI builds images but does not run Terraform, use one of these handoff patterns:

- copy the CI-produced SHA/tag and pass it manually with `-var="image_tag=..."`
- have CI publish the built tag as an artifact or release note
- have CI write the approved image tag to a small deployment record such as SSM
  Parameter Store, then make Terraform read that value explicitly

Avoid relying only on a mutable tag such as `latest` or `stage`: Terraform will
not see the image contents change when the tag name stays the same, so the EC2
instance will not be replaced unless you also change `image_tag` or force a
replacement.

Troubleshoot bootstrap through SSM and cloud-init/systemd logs:

```sh
terraform output ssm_start_session_command
sudo tail -n 200 /var/log/cidr-calculator-user-data.log
sudo journalctl -u cidr-calculator.service --no-pager
```

Destroy lab resources:

```sh
terraform destroy
```
