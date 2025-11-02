locals {
  /* Retain case in IAM role names if no separator
  This module supports an input variable that defines the character used to separate
  words in the IAM role name. IAM roles are commonly named in either `PascalCase` or
  `lowercase-with-separators`. This local preserves case if there is no separator
  and if the role name prefix is written in mixed-case (`GitHubActionsOIDCOwnerRepo`),
  or lowercases the name if there is a separator (`github-actions-oidc-owner-repo`). */
  aws_iam_role_name_defaults = {
    for repo in var.github_repos :
    lower(replace(repo, "/", "-")) => join(
      var.aws_iam_role_separator,
      [
        var.aws_iam_role_prefix,
        var.aws_iam_role_prefix != lower(var.aws_iam_role_prefix) && var.aws_iam_role_separator == ""
        ? replace(repo, "/", var.aws_iam_role_separator)
        : replace(lower(repo), "/", var.aws_iam_role_separator)
      ]
    )
  }
  aws_iam_roles = merge([
    for key, value in local.github_repos : can(tomap(try(var.aws_iam_role_names[value], ""))) ? {
      for role_name, claims in var.aws_iam_role_names[value] :
      "${key}-${substr(role_name, 0, 64)}" => {
        claims    = claims
        repo      = value
        role_name = substr(role_name, 0, 64)
      }
      } : {
      "${key}" = {
        claims    = [var.github_custom_claim]
        repo      = value
        role_name = substr(try(var.aws_iam_role_names[value], local.aws_iam_role_name_defaults[key]), 0, 64)
      }
    }
  ]...)
  github_repos       = { for repo in var.github_repos : lower(replace(repo, "/", "-")) => repo }
  oidc_client_ids    = ["sts.amazonaws.com"]
  oidc_issuer_domain = "token.actions.githubusercontent.com"
}

# Fetch TLS certificate thumbprint from OIDC provider

data "tls_certificate" "github" {
  url = "https://${local.oidc_issuer_domain}/.well-known/openid-configuration"
}

# Create a single GitHub Actions OIDC provider

resource "aws_iam_openid_connect_provider" "github" {
  client_id_list  = local.oidc_client_ids
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
  url             = "https://${local.oidc_issuer_domain}"
}

# Define resource-based role trust policy for each IAM role
# https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_identity-vs-resource.html

data "aws_iam_policy_document" "role_trust_policy" {
  for_each = local.aws_iam_roles
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity", "sts:TagSession"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_domain}:aud"
      values   = local.oidc_client_ids
    }
    condition {
      test     = "StringLike"
      variable = "${local.oidc_issuer_domain}:sub"
      values   = [for claim in each.value.claims : "repo:${each.value.repo}:${claim}"]
    }
  }
}

# Create IAM roles for each repo and attach a role trust policy to each role
# https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp.html

resource "aws_iam_role" "github_actions_oidc" {
  for_each           = local.aws_iam_roles
  assume_role_policy = data.aws_iam_policy_document.role_trust_policy[each.key].json
  description        = "IAM assumed role for GitHub Actions in the ${each.value.repo} repo"
  name               = each.value.role_name
}
