terraform {
  cloud {
    hostname     = "app.terraform.io"
    organization = "<YOUR_TERRAFORM_CLOUD_ORG>"
    workspaces {
      name = "aws-github-actions-oidc"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = "~> 1.0"
}
