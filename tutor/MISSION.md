# Mission: Migrate AWS EC2 lab to Google Compute Engine

## Why
Migrate `labs/05-static-site-ec2/` from AWS EC2/ECR/IAM to Google Cloud Compute Engine/Artifact Registry/IAM without copying AWS habits blindly. The immediate blocker is understanding Google Cloud IAM and local CLI authentication well enough to design the GCP lab safely.

## Success looks like
- Explain the GCP equivalents of IAM Identity Center permission sets, IAM roles, EC2 instance profiles, and GitHub OIDC roles.
- Use `gcloud` safely in a terminal session: know the active account, project, configuration, ADC credentials, and impersonated service account.
- Design the first GCE Terraform lab with least-privilege service accounts and no long-lived service account keys.
- Debug “which identity am I using?” problems before running Terraform or Docker/Artifact Registry commands.

## Constraints
- Teach by mapping from the user’s existing AWS mental model.
- Keep lessons short and directly tied to the migration lab.
- Prefer Google Cloud best practices over direct AWS feature-for-feature translation.

## Out of scope
- Production multi-project/folder organization design beyond what is needed to safely build the first GCE migration lab.
- Kubernetes/GKE.
