# GCP IAM and Auth Resources

## Knowledge

- [Google Cloud: IAM overview](https://docs.cloud.google.com/iam/docs/overview)
  Canonical model for principals, roles, resources, allow policies, hierarchy inheritance, deny policies, principal access boundaries, and IAM Conditions. Use for: any IAM mental-model question.
- [Google Cloud: Authentication for Google Cloud APIs and services](https://docs.cloud.google.com/docs/authentication)
  Official authentication decision tree for gcloud, local development, ADC, service account impersonation, attached service accounts, workload/workforce federation, and service account keys. Use for: choosing the correct auth method.
- [Google Cloud: How Application Default Credentials works](https://docs.cloud.google.com/docs/authentication/application-default-credentials)
  Explains ADC lookup order and the crucial split between gcloud CLI credentials and ADC credentials. Use for: Terraform/provider/client-library auth debugging.
- [Google Cloud SDK: `gcloud auth login`](https://docs.cloud.google.com/sdk/gcloud/reference/auth/login)
  Reference for local gcloud login, active accounts, browser/no-browser login, `--update-adc`, and federation credential files. Use for: terminal-session setup.
- [Google Cloud SDK: Authenticate for the gcloud CLI](https://docs.cloud.google.com/sdk/docs/authenticate)
  Detailed guide to gcloud credential priority, active principals, impersonation overrides, access-token overrides, and Docker credential helper setup. Use for: explaining why `gcloud auth login` and ADC differ.
- [Google Cloud SDK: `gcloud auth application-default login`](https://docs.cloud.google.com/sdk/gcloud/reference/auth/application-default/login)
  Command reference for writing local ADC credentials, quota project behavior, scopes, and the fact that it does not affect `gcloud auth login` accounts. Use for: local Terraform/client-library setup.
- [Google Cloud: Service accounts overview](https://docs.cloud.google.com/iam/docs/service-account-overview)
  Explains service accounts as both principals and resources, attached service accounts, impersonation, and service account key risks. Use for: mapping EC2 instance profiles and GitHub/OIDC deployment roles to GCP.
- [Google Cloud: Use service account impersonation](https://docs.cloud.google.com/docs/authentication/use-service-account-impersonation)
  Official guide for using short-lived service account credentials from gcloud or ADC instead of service account keys. Use for: local Terraform and per-command deploy identity patterns.
- [Google Cloud: Configure Workload Identity Federation with deployment pipelines](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines)
  Official deployment-pipeline federation guide covering GitHub OIDC claim mapping, attribute conditions, service account impersonation, and generated credential files. Use for: GitHub Actions plan/push/apply authentication design.
- [Google Cloud: Create a VM that uses a user-managed service account](https://docs.cloud.google.com/compute/docs/access/create-enable-service-accounts-for-instances)
  Compute Engine guide recommending user-managed VM service accounts and cloud-platform scope bounded by IAM. Use for: mapping EC2 instance profiles to GCE metadata credentials.
- [GitHub: google-github-actions/auth](https://github.com/google-github-actions/auth)
  Maintained GitHub Action for Google Cloud authentication; documents WIF, generated credential files, required GitHub permissions, and service account key caveats. Use for: workflow YAML examples after the conceptual model is clear.

## Wisdom (Communities)

- [Google Cloud Community](https://www.googlecloudcommunity.com/)
  Official community forum. Use for: practical IAM and gcloud questions after reproducing a problem with exact commands and error messages.
- [Stack Overflow: google-cloud-iam](https://stackoverflow.com/questions/tagged/google-cloud-iam)
  Public Q&A with many real-world failure modes. Use for: debugging specific IAM denied errors; verify answers against official docs.

## Gaps

- Need migration-specific resources for Artifact Registry Docker auth and Terraform Google provider impersonation before writing the actual GCE lab.
