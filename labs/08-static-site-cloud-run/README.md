# Lab 08: Static Site on Cloud Run

Terraform tracer bullet for serving the shared CIDR Calculator container on Google Cloud Run.

The lab consumes an image that has already been built from `../../apps/cidr-calculator/`, pushed to the canonical ECR repository, and mirrored into the Lab 08 Artifact Registry repository with an immutable `sha-<git-sha>` tag. Terraform does not build images and does not infer tags.

## Bootstrap prerequisites

1. Apply `infra/bootstrap/gcp` to create the shared GCS Terraform state bucket, required APIs, and GitHub Workload Identity Federation foundations.
2. Apply `labs/08-static-site-cloud-run/infra/bootstrap` to create the durable Lab 08 ECR repository, Artifact Registry mirror, CI identities, and runtime state prefix.
3. Use the approved deploy workflow to build/push the canonical ECR image, mirror the exact immutable tag into Artifact Registry, and apply this runtime root.

Runtime destroy intentionally leaves bootstrap resources intact: ECR image history, Artifact Registry repository, cloud identities/roles, Workload Identity Federation, and GCS/Terraform state foundations survive.

## Infrastructure layout

- Reusable module: `infra/modules/cloud-run-static-site`
- Stage root: `infra/stage`

The runtime provisions:

- a dedicated Cloud Run runtime service account
- a public Cloud Run v2 service with unauthenticated `roles/run.invoker`
- scale-to-zero default (`min_instance_count = 0`)
- max instance guardrail (`max_instance_count = 2` by default and capped at 2)
- small lab-sized CPU/memory defaults (`1` CPU, `256Mi` memory)
- explicit container port `80`
- no VPC connector
- outputs for URL, image, scaling, service account, smoke test, and inspection commands

## Configure remote state

```sh
cd labs/08-static-site-cloud-run/infra/stage
cp backend.hcl.example backend.hcl
$EDITOR backend.hcl # set bucket from shared GCP bootstrap output state_bucket_name
terraform init -backend-config=backend.hcl
```

The committed backend example uses placeholder values only. The intended state prefix is:

```text
gcp/runtime/labs/08-static-site-cloud-run/stage
```

For local syntax and contract validation before configuring remote state:

```sh
terraform init -backend=false
terraform fmt -recursive -check ../..
terraform validate
terraform test
```

## Configure variables

```sh
cp stage.auto.tfvars.example stage.auto.tfvars
$EDITOR stage.auto.tfvars
```

Set account-specific values locally only:

```hcl
gcp_project_id                  = "YOUR_GCP_PROJECT_ID"
artifact_registry_repository_id = "REPOSITORY_ID_FROM_LAB_08_BOOTSTRAP"
image_tag                       = "sha-YOUR_40_CHAR_GIT_SHA"
```

The stage constructs the deployable image reference as:

```text
<GCP_REGION>-docker.pkg.dev/<GCP_PROJECT_ID>/<ARTIFACT_REGISTRY_REPOSITORY_ID>/<SERVICE_NAME>:<IMAGE_TAG>
```

## Image mirror prerequisite

ECR remains the canonical image store. Before applying Cloud Run, mirror the already-pushed immutable ECR tag to Artifact Registry:

```sh
IMAGE_TAG="sha-0123456789abcdef0123456789abcdef01234567"
ECR_REPOSITORY_URL="REPLACE_WITH_LAB_08_ECR_REPOSITORY_URL"
GCP_PROJECT_ID="YOUR_GCP_PROJECT_ID"
GCP_REGION="asia-northeast1"
ARTIFACT_REPOSITORY_ID="REPOSITORY_ID_FROM_LAB_08_BOOTSTRAP"
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

## Local validation and optional plan

The normal provisioning path is **Approved Deploy** through GitHub Actions, not local `terraform apply`. Use local Terraform commands to validate the Runtime Stage before opening a PR or requesting an approved deploy:

```sh
cd labs/08-static-site-cloud-run/infra/stage
terraform init -backend=false
terraform fmt -recursive -check ../..
terraform validate
terraform test
```

If you have configured `backend.hcl` and `stage.auto.tfvars` locally, you can also run a plan-only preview without changing live infrastructure:

```sh
terraform init -backend-config=backend.hcl
terraform plan
```

The approved apply completes after Cloud Run creates a new revision from the provided Artifact Registry image tag.

## Smoke test

```sh
SERVICE_URL=$(terraform output -raw service_url)
curl -fsS "$SERVICE_URL" | grep -F "CIDR Calculator"
```

Open the HTTPS URL in a browser to confirm the static CIDR calculator loads. Useful inspection commands:

```sh
terraform output service_name
terraform output container_image
terraform output runtime_service_account_email
terraform output runtime_scaling
terraform output describe_service_command
terraform output list_revisions_command
```

## AWS ECS to Cloud Run comparison

| Lab 06 ECS-style managed container | Lab 08 Cloud Run |
|---|---|
| Deploys the same CIDR Calculator image from canonical ECR | Deploys the mirrored Artifact Registry copy of the same immutable tag |
| Managed service/revision abstracts servers and load balancing | Fully serverless service/revision abstracts servers and load balancing |
| HTTPS endpoint from ECS Express Mode | Default Cloud Run HTTPS URL |
| ECS task execution/task roles | Dedicated Cloud Run runtime service account |
| Minimum task count generally keeps capacity warm | `min_instance_count = 0` scales to zero while idle |
| Auto scaling guardrails through service scaling settings | `max_instance_count = 2` caps burst scale for the lab |
| CloudWatch logs and ECS service inspection | Cloud Logging by default plus `gcloud run` service/revision inspection |
| Optional/default managed networking in the AWS runtime | No VPC connector; public ingress directly to Cloud Run |

## Approved deploy and destroy workflows

Create GitHub Environment `lab-08-stage` before using deploy/destroy, and configure its required reviewers in the GitHub repository settings.

Use `.github/workflows/gcp-runtime-deploy.yml` with `lab=08-static-site-cloud-run` as the normal provisioning path. The workflow runs app checks, Docker smoke tests, Terraform validation, `terraform test`, and a pre-approval plan. After `lab-08-stage` approval, it mirrors the immutable image tag into Artifact Registry and applies only Runtime Stage resources in `labs/08-static-site-cloud-run/infra/stage`.

Use `.github/workflows/gcp-runtime-destroy.yml` for gated runtime teardown:

1. Run **GCP runtime destroy** manually from GitHub Actions.
2. Select `08-static-site-cloud-run`.
3. Approve the `lab-08-stage` GitHub Environment prompt.

After approval, the workflow authenticates to GCP through Workload Identity Federation as `devops-cloudrun-stage-apply@portfolio-devops-labs.iam.gserviceaccount.com`, initializes only `labs/08-static-site-cloud-run/infra/stage`, and runs `terraform destroy` against the runtime state prefix `gcp/runtime/labs/08-static-site-cloud-run/stage`. It does not initialize or destroy the shared GCP bootstrap root or the Lab 08 bootstrap root.

The workflow validates teardown by confirming the previous HTTPS endpoint no longer responds, the Cloud Run service is no longer describable, and durable GCP bootstrap resources remain addressable: the GCS state bucket, Artifact Registry repository, apply service account, and apply custom role. AWS-side ECR image history is intentionally outside this GCP-only runtime destroy path and remains owned by the Lab 08 bootstrap resources.

## Teardown semantics

Destroy only the disposable Cloud Run Runtime Stage through the approved destroy workflow. Destroy removes only Runtime Stage resources: the Cloud Run service and its dedicated runtime service account. It does not remove the shared GCP bootstrap, Lab 08 bootstrap, ECR repository, Artifact Registry repository, image history, Workload Identity Federation, plan/apply service accounts, custom roles, GitHub identities, budgets, or GCS/Terraform state foundations.
