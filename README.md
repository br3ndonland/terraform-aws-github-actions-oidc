# GitHub Actions OpenID Connect

## Description

GitHub has [introduced](https://github.blog/changelog/2021-10-27-github-actions-secure-cloud-deployments-with-openid-connect/) OpenID Connect ("OIDC") for GitHub Actions (see [roadmap](https://github.com/github/roadmap/issues/249) and [docs](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments)). OIDC allows workflows to authenticate with AWS by assuming [IAM roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_terms-and-concepts.html) that grant temporary security credentials, instead of by using static AWS access keys stored in GitHub Secrets. See the AWS IAM docs on [creating OIDC providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html) and [creating roles for OIDC providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp.html), and the [GitHub OIDC docs for AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services) for further info related to AWS.

The [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials) repo recommends OIDC, but only provides a CloudFormation snippet. The implementation in this repo is the Terraform equivalent. The [AWS Terraform provider](https://registry.terraform.io/providers/hashicorp/aws/latest) includes an [`iam_openid_connect_provider`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) resource for OIDC.

This Terraform module is published to the public Terraform module registry [here](https://registry.terraform.io/modules/br3ndonland/github-actions-oidc/aws/latest). It was originally published to my Terraform Cloud private module registry with a custom script available [here](https://gist.github.com/br3ndonland/2e3665a8117b5594b00f3d556d33cd57). In addition to this module, see other implementations from Cloud Posse ([repo](https://github.com/cloudposse/terraform-aws-components/tree/main/modules/github-oidc-provider), [docs](https://docs.cloudposse.com/components/library/aws/github-oidc-provider/)) and terraform-aws-modules ([repo](https://github.com/terraform-aws-modules/terraform-aws-iam), [docs](https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest)).

## Required permissions

[Authentication is required for the AWS Terraform provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication) so that Terraform can apply configurations using this module. The [IAM best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html) recommend granting least privilege.

<details><summary>Here are the minimum required permissions for running this module <em>(expand)</em>. Adjust the resource names as needed.</summary>

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "IAMOIDCProviderProvisioningActions",
      "Effect": "Allow",
      "Action": [
        "iam:AddClientIDToOpenIDConnectProvider",
        "iam:CreateOpenIDConnectProvider",
        "iam:TagOpenIDConnectProvider",
        "iam:UpdateOpenIDConnectProviderThumbprint"
      ],
      "Resource": [
        "arn:aws:iam::*:oidc-provider/token.actions.githubusercontent.com"
      ]
    },
    {
      "Sid": "IAMOIDCProviderReadActions",
      "Effect": "Allow",
      "Action": [
        "iam:GetOpenIDConnectProvider",
        "iam:ListOpenIDConnectProviders",
        "iam:ListOpenIDConnectProviderTags"
      ],
      "Resource": ["*"]
    },
    {
      "Sid": "IAMOIDCProviderCleanupActions",
      "Effect": "Allow",
      "Action": [
        "iam:DeleteOpenIDConnectProvider",
        "iam:RemoveClientIDFromOpenIDConnectProvider",
        "iam:UntagOpenIDConnectProvider"
      ],
      "Resource": [
        "arn:aws:iam::*:oidc-provider/token.actions.githubusercontent.com"
      ]
    },
    {
      "Sid": "IAMRoleProvisioningActions",
      "Effect": "Allow",
      "Action": [
        "iam:AttachRolePolicy",
        "iam:CreateRole",
        "iam:PutRolePolicy",
        "iam:UpdateRole",
        "iam:UpdateRoleDescription",
        "iam:UpdateAssumeRolePolicy"
      ],
      "Resource": ["arn:aws:iam::*:role/github*"]
    },
    {
      "Sid": "IAMRoleReadActions",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:ListAttachedRolePolicies",
        "iam:ListInstanceProfilesForRole",
        "iam:ListRolePolicies",
        "iam:ListRoles"
      ],
      "Resource": ["*"]
    },
    {
      "Sid": "IAMRoleCleanupActions",
      "Effect": "Allow",
      "Action": [
        "iam:DeleteRole",
        "iam:DeleteRolePolicy",
        "iam:DetachRolePolicy"
      ],
      "Resource": ["arn:aws:iam::*:role/github*"]
    },
    {
      "Sid": "IAMPolicyProvisioningActions",
      "Effect": "Allow",
      "Action": ["iam:CreatePolicy", "iam:CreatePolicyVersion"],
      "Resource": ["arn:aws:iam::*:policy/github*"]
    },
    {
      "Sid": "IAMPolicyReadActions",
      "Effect": "Allow",
      "Action": [
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListEntitiesForPolicy",
        "iam:ListPolicies",
        "iam:ListPolicyVersions",
        "iam:ListUserPolicies"
      ],
      "Resource": ["*"]
    },
    {
      "Sid": "IAMPolicyCleanupActions",
      "Effect": "Allow",
      "Action": ["iam:DeletePolicy", "iam:DeletePolicyVersion"],
      "Resource": ["arn:aws:iam::*:policy/github*"]
    }
  ]
}
```

</details>

## Usage

- Configure a [backend](https://developer.hashicorp.com/terraform/language/settings/backends/configuration) for Terraform state.
- Set [Terraform input variables](https://developer.hashicorp.com/terraform/language/values/variables), either with variables set in a remote state workspace, by passing variable values in to the `terraform` CLI command directly with `-var`, or with a `.tfvars` file. Variable definitions files named `terraform.tfvars` or `*.auto.tfvars` will be loaded automatically. If using a variable definitions file with a different name, use `-var-file=filename.tfvars`.
- Next, declare Terraform configurations specific to the repos and policies you want to configure. See the _examples/_ directory for example configurations. The module can be [used](https://developer.hashicorp.com/terraform/registry/modules/use) by adding a `module` block, as shown in the [example](examples/s3/main.tf).
- Then, [initialize and apply](https://developer.hashicorp.com/terraform/intro/core-workflow) the Terraform configuration.

## Code quality

- Terraform should be formatted with [`terraform fmt`](https://developer.hashicorp.com/terraform/cli/commands/fmt).
- Shell scripts should be formatted with [`shfmt`](https://github.com/mvdan/sh), with two space indentations (`shfmt -i 2 -w .`), and will also be checked for errors with [ShellCheck](https://github.com/koalaman/shellcheck) (`shellcheck **/*.sh -S error`).
- Other web code (JSON, Markdown, YAML) should be formatted with [Prettier](https://prettier.io/).
