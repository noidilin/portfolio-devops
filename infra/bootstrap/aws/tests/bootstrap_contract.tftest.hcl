mock_provider "aws" {}

override_resource {
  target          = aws_iam_openid_connect_provider.github
  override_during = plan
  values = {
    arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  }
}

run "aws_account_bootstrap_contract" {
  command = plan

  assert {
    condition     = aws_iam_openid_connect_provider.github.url == "https://token.actions.githubusercontent.com"
    error_message = "The shared AWS bootstrap must create the canonical GitHub Actions OIDC issuer."
  }

  assert {
    condition     = jsonencode(sort(tolist(aws_iam_openid_connect_provider.github.client_id_list))) == jsonencode(["sts.amazonaws.com"])
    error_message = "The GitHub OIDC provider must allow only the AWS STS audience."
  }

  assert {
    condition     = length(tolist(aws_iam_openid_connect_provider.github.thumbprint_list)) == 0
    error_message = "The GitHub OIDC provider should rely on AWS-managed thumbprints."
  }

  assert {
    condition     = aws_iam_openid_connect_provider.github.tags["Project"] == "devops-lab-cicd" && aws_iam_openid_connect_provider.github.tags["Environment"] == "bootstrap" && aws_iam_openid_connect_provider.github.tags["ManagedBy"] == "terraform"
    error_message = "The account bootstrap OIDC provider should carry the canonical bootstrap tags."
  }

  assert {
    condition     = output.github_oidc_provider_arn == aws_iam_openid_connect_provider.github.arn
    error_message = "The bootstrap output must expose the GitHub OIDC provider ARN for operator confirmation."
  }
}
