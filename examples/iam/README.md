# IAM policy examples

## GitHub Actions OIDC provisioning

[Credentials are required for the AWS Terraform provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication) so that Terraform can apply the configurations in this repo. If using Terraform Cloud, credentials need to be specified there. The [IAM best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html) recommend granting least privilege, so it is preferable to configure Terraform Cloud with only the minimal permissions it needs. This example demonstrates how to set up AWS credentials for Terraform Cloud state workspaces.

### IAM roles

Terraform Cloud added support for assuming roles with OIDC in March 2023. See the [blog post](https://www.hashicorp.com/blog/dynamic-provider-credentials-now-ga-for-terraform-cloud) and the [Terraform Cloud docs on "dynamic provider credentials"](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials).

### IAM users

AWS access keys from IAM users can be stored as [Terraform Cloud variables](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/variables). Be sure to set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as _environment_ variables, not _Terraform_ variables, otherwise `Warning: Value for undeclared variable` may be seen. See the [AWS docs on creating OIDC identity providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html) for more info on the IAM permissions required.

[AWS CLI IAM commands](https://docs.aws.amazon.com/cli/latest/reference/iam/index.html) look like this:

```sh
aws iam create-group \
  --group-name terraform-cloud

aws iam create-user \
  --user-name github-actions-oidc

aws iam add-user-to-group \
  --group-name terraform-cloud \
  --user-name github-actions-oidc

aws iam put-user-policy \
  --user-name github-actions-oidc \
  --policy-name github-actions-oidc-provisioning \
  --policy-document file://github-actions-oidc-provisioning.json

aws iam create-access-key \
  --user-name github-actions-oidc
```

The above commands can be performed with Terraform as well. See:

- [`aws_iam_group`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group)
- [`aws_iam_user`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user)
- [`aws_iam_user_policy`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy)

The access key credentials can then be set as Terraform Cloud workspace variables.

| Key                               | Category |
| --------------------------------- | -------- |
| AWS_ACCESS_KEY_ID                 | env      |
| AWS_SECRET_ACCESS_KEY `SENSITIVE` | env      |
