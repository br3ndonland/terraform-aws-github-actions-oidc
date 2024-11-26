locals {
  github_repos = {
    for repo in var.github_repos_with_oidc :
    replace(repo, "/", "-") => {
      owner = split("/", repo)[0]
      repo  = split("/", repo)[1]
    }
  }
}

# Call module
# https://opentofu.org/docs/language/modules/sources/
module "github_actions_oidc" {
  source       = "github.com/br3ndonland/tofu-aws-github-actions-oidc"
  github_repos = var.github_repos_with_oidc
}

# Define identity-based policies for IAM role (what the role can do after it has been assumed)
# https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_identity-vs-resource.html
# For each repo with OIDC, this policy will allow access to an S3 bucket with the same name.
data "aws_iam_policy_document" "s3_bucket_for_oidc" {
  for_each = local.github_repos
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${each.value.repo}"]
  }
  statement {
    actions   = ["s3:DeleteObject", "s3:GetObject", "s3:PutObject"]
    resources = ["arn:aws:s3:::${each.value.repo}/*"]
  }
}

resource "aws_iam_policy" "s3_bucket_for_oidc" {
  for_each    = local.github_repos
  name        = "github-actions-s3-${each.value.repo}"
  description = "Allows access to a single S3 bucket with the given name"
  policy      = data.aws_iam_policy_document.s3_bucket_for_oidc[each.key].json
}

# Attach identity-based policies to IAM role
resource "aws_iam_role_policy_attachment" "s3_bucket_for_oidc" {
  for_each   = aws_iam_policy.s3_bucket_for_oidc
  role       = module.github_actions_oidc.aws_iam_roles[each.key].name
  policy_arn = each.value.arn
}
