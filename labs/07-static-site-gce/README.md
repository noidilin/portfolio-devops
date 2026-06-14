# Lab 07: Static Site on GCE

Terraform tracer bullet for serving the shared CIDR Calculator container on one small Google Compute Engine VM running Docker.

The lab consumes an image that has already been built from `../../apps/cidr-calculator/`, pushed to the canonical ECR repository, and mirrored into the Lab 07 Artifact Registry repository with an immutable `sha-<git-sha>` tag. Terraform does not build images and does not infer tags.

## Bootstrap prerequisites

1. Apply `infra/gcp-bootstrap/shared-project` to create the shared GCS Terraform state bucket, required APIs, and GitHub Workload Identity Federation foundations.
2. Apply `labs/07-static-site-gce/infra/bootstrap` to create the durable Lab 07 ECR repository, Artifact Registry mirror, CI identities, and runtime state prefix.
3. Mirror the exact immutable image tag you want to deploy into Artifact Registry before applying this runtime root.

Runtime destroy intentionally leaves bootstrap resources intact: ECR image history, Artifact Registry repository, CI identities, and GCS state bucket survive.

## Infrastructure layout

- Reusable module: `infra/modules/gce-docker-runtime`
- Stage root: `infra/stage`

The runtime provisions:

- a dedicated VPC and regional subnet
- public HTTP firewall ingress to port 80
- no public SSH ingress
- IAP-compatible SSH firewall ingress from `35.235.240.0/20`
- a dedicated runtime service account with Artifact Registry read access
- one Ubuntu 24.04 LTS GCE VM (`e2-micro` by default)
- OS Login metadata
- an auto-delete boot disk
- a startup script that installs Docker, authenticates to Artifact Registry with the VM service account token, pulls the requested image, and runs it on host port 80
- deterministic VM replacement when the image tag changes
- outputs for URL, public IP, image, network, smoke test, startup logs, and IAP debugging

## Configure remote state

```sh
cd labs/07-static-site-gce/infra/stage
cp backend.hcl.example backend.hcl
$EDITOR backend.hcl # set bucket from shared GCP bootstrap output state_bucket_name
terraform init -backend-config=backend.hcl
```

The committed backend example uses placeholder values only. The intended state prefix is:

```text
gcp/runtime/labs/07-static-site-gce/stage
```

For local syntax validation before configuring remote state:

```sh
terraform init -backend=false
terraform validate
```

## Configure variables

```sh
cp stage.auto.tfvars.example stage.auto.tfvars
$EDITOR stage.auto.tfvars
```

Set account-specific values locally only:

```hcl
gcp_project_id                  = "YOUR_GCP_PROJECT_ID"
artifact_registry_repository_id = "REPOSITORY_ID_FROM_LAB_07_BOOTSTRAP"
image_tag                       = "sha-YOUR_40_CHAR_GIT_SHA"
```

The stage constructs the deployable image reference as:

```text
<GCP_REGION>-docker.pkg.dev/<GCP_PROJECT_ID>/<ARTIFACT_REGISTRY_REPOSITORY_ID>/<SERVICE_NAME>:<IMAGE_TAG>
```

## Image mirror prerequisite

ECR remains the canonical image store. Before applying GCE, mirror the already-pushed immutable ECR tag to Artifact Registry:

```sh
IMAGE_TAG="sha-0123456789abcdef0123456789abcdef01234567"
ECR_REPOSITORY_URL="REPLACE_WITH_LAB_07_ECR_REPOSITORY_URL"
GCP_PROJECT_ID="YOUR_GCP_PROJECT_ID"
GCP_REGION="asia-northeast1"
ARTIFACT_REPOSITORY_ID="REPOSITORY_ID_FROM_LAB_07_BOOTSTRAP"
SERVICE_NAME="cidr-calculator"
AR_IMAGE="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${ARTIFACT_REPOSITORY_ID}/${SERVICE_NAME}:${IMAGE_TAG}"

docker pull "${ECR_REPOSITORY_URL}:${IMAGE_TAG}"
docker tag "${ECR_REPOSITORY_URL}:${IMAGE_TAG}" "${AR_IMAGE}"
gcloud auth configure-docker "${GCP_REGION}-docker.pkg.dev" --project "${GCP_PROJECT_ID}"
docker push "${AR_IMAGE}"
```

You can also inspect generated mirror commands after Terraform init:

```sh
terraform output docker_mirror_commands
```

## Manual plan/apply flow

```sh
cd labs/07-static-site-gce/infra/stage
terraform fmt -recursive ../..
terraform validate
terraform plan
terraform apply
```

The apply completes after the VM is created. The startup script then installs Docker and starts the container; this can take a few minutes after Terraform reports success.

## Smoke test

```sh
SERVICE_URL=$(terraform output -raw service_url)
curl -fsS "$SERVICE_URL" | grep -F "CIDR Calculator"
```

Open the HTTP URL in a browser to confirm the static CIDR calculator loads. Useful inspection outputs:

```sh
terraform output public_ip
terraform output container_image
terraform output runtime_service_account_email
terraform output smoke_test_command
terraform output serial_port_logs_command
terraform output iap_ssh_command
terraform output docker_status_command
```

## IAP and OS Login debugging

This lab does not open SSH to the internet. Debug failed startup scripts through IAP TCP forwarding and OS Login:

```sh
$(terraform output -raw iap_ssh_command)
```

After connecting, inspect Docker and container status:

```sh
sudo systemctl status docker --no-pager
sudo docker ps --filter name=cidr-calculator
sudo docker logs cidr-calculator --tail 100
```

If SSH is not yet available, inspect serial output from your local terminal:

```sh
$(terraform output -raw serial_port_logs_command)
```

## AWS EC2 to GCE comparison

| Lab 05 EC2 Docker runtime | Lab 07 GCE Docker runtime |
|---|---|
| Single EC2 instance runs Docker from user data | Single GCE VM runs Docker from startup script |
| Amazon Linux/EC2 AMI path | Ubuntu 24.04 LTS image family |
| EC2 instance type | GCE `e2-micro` machine type |
| VPC/subnet/security group model | Dedicated VPC/subnet/firewall rule model |
| Public HTTP on port 80 | Public HTTP on port 80 |
| No direct app build in Terraform | No direct app build in Terraform |
| ECR image consumed by EC2 Docker | Artifact Registry mirror consumed by GCE Docker |
| EC2 instance profile | Dedicated GCE runtime service account |
| SSM Session Manager for inspection | OS Login plus IAP TCP forwarding for SSH |
| User-data/image changes can replace host | Image tag changes trigger deterministic VM replacement |

## Teardown semantics

Destroy only the disposable GCE runtime:

```sh
cd labs/07-static-site-gce/infra/stage
terraform destroy
```

This removes the VM, auto-delete boot disk, ephemeral public IP, firewall rules, VPC/subnet, runtime service account, and runtime IAM binding. It does not remove the shared GCP bootstrap, Lab 07 bootstrap, ECR repository, Artifact Registry repository, image history, GitHub identities, or GCS state bucket.
