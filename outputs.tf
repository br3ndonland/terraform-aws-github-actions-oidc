output "aws_iam_roles" {
  description = "ARNs and names of AWS IAM roles that have been provisioned"
  value = {
    for key, value in aws_iam_role.github_actions_oidc :
    key => {
      arn  = value.arn
      name = value.name
      repo = local.aws_iam_roles[key].repo
    }
  }
}
