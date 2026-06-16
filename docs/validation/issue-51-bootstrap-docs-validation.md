# Issue 51 bootstrap documentation and validation notes

Date: 2026-06-16

## Documentation alignment

Bootstrap READMEs now use the canonical sections: Purpose, Prerequisites, Configure backend and variables, Validate and apply, Durable resources, CI/CD consumers, and Runtime destroy boundary.

Checked roots:

- `infra/account-bootstrap/github-oidc-provider/README.md`
- `infra/gcp-bootstrap/shared-project/README.md`
- `labs/05-static-site-ec2/infra/bootstrap/README.md`
- `labs/06-static-site-ecs/infra/bootstrap/README.md`
- `labs/07-static-site-gce/infra/bootstrap/README.md`
- `labs/08-static-site-cloud-run/infra/bootstrap/README.md`

Central docs now record the AWS external-prerequisite model, the GCP shared-project bootstrap model, the per-lab bootstrap relationship, and the manual sequence from AWS sandbox prerequisites through Lab 08 bootstrap and PR CI/live-plan reruns:

- `infra/README.md`
- `infra/gcp-bootstrap/README.md`
- `infra/gcp-bootstrap/shared-project/README.md`
- `docs/plan-bootstrap-alignment.md`

Lab READMEs and bootstrap READMEs reference the canonical bootstrap names, outputs, GitHub Environment subjects, and runtime destroy boundaries. Local apply guidance is limited to human bootstrap setup and plan-only runtime previews; the learner provisioning path remains approved deploy/destroy workflows.

## Terraform validation results

All commands were run locally on 2026-06-16.

| Root | fmt | init -backend=false | validate | test |
| --- | --- | --- | --- | --- |
| `infra/account-bootstrap/github-oidc-provider` | pass | pass | pass | n/a |
| `infra/gcp-bootstrap/shared-project` | pass | pass | pass | pass, 1 passed |
| `labs/05-static-site-ec2/infra/bootstrap` | pass | pass | pass | pass, 2 passed |
| `labs/06-static-site-ecs/infra/bootstrap` | pass | pass | pass | pass, 2 passed |
| `labs/07-static-site-gce/infra/bootstrap` | pass | pass | pass | pass, 2 passed |
| `labs/08-static-site-cloud-run/infra/bootstrap` | pass | pass | pass | pass, 1 passed |

Commands used:

```sh
terraform -chdir=<root> fmt -check -recursive
terraform -chdir=<root> init -backend=false -input=false
terraform -chdir=<root> validate
terraform -chdir=<root> test # where tests/ exists
```

## Drift-check results

Tracked real backend files:

```sh
git ls-files '**/backend.hcl'
# no output
```

Broad GCP plan principal sets in per-lab bootstrap roots:

```sh
rg -n 'principalSet://iam.googleapis.com/.*/attribute.repository' \
  labs/07-static-site-gce/infra/bootstrap \
  labs/08-static-site-cloud-run/infra/bootstrap
# no output
```

AWS plan workflow-file trust condition in Terraform implementation code:

```sh
rg -n 'job_workflow_ref' --glob '!**/tests/**' \
  labs/05-static-site-ec2/infra/bootstrap \
  labs/06-static-site-ecs/infra/bootstrap \
  labs/07-static-site-gce/infra/bootstrap \
  labs/08-static-site-cloud-run/infra/bootstrap
# no output
```

Deprecated Lab 07/08 variable/output names:

```sh
rg -n 'variable "terraform_state_bucket_name"|output "runtime_state_prefix"|output "terraform_state_bucket_name"|variable "artifact_cleanup_|variable "tags"|variable "labels"|github_wif_pool_id|github_wif_provider_id' \
  labs/07-static-site-gce/infra/bootstrap \
  labs/08-static-site-cloud-run/infra/bootstrap
# no output
```

Canonical README section check:

```sh
for f in \
  infra/account-bootstrap/github-oidc-provider/README.md \
  infra/gcp-bootstrap/shared-project/README.md \
  labs/05-static-site-ec2/infra/bootstrap/README.md \
  labs/06-static-site-ecs/infra/bootstrap/README.md \
  labs/07-static-site-gce/infra/bootstrap/README.md \
  labs/08-static-site-cloud-run/infra/bootstrap/README.md; do
  rg -q '^## Purpose$' "$f" && \
  rg -q '^## Prerequisites$' "$f" && \
  rg -q '^## Configure backend and variables$' "$f" && \
  rg -q '^## Validate and apply$' "$f" && \
  rg -q '^## Durable resources$' "$f" && \
  rg -q '^## CI/CD consumers$' "$f" && \
  rg -q '^## Runtime destroy boundary$' "$f"
done
# all checked files passed
```

Note: the Lab 07 contract test intentionally contains the string `job_workflow_ref` inside a negative assertion proving the AWS plan trust policy does not include that condition. The drift check above excludes tests when checking implementation trust configuration.
