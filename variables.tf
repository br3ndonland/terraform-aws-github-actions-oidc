variable "aws_iam_role_names" {
  description = <<-DESCRIPTION
    Optional mapping of GitHub repos to names of IAM roles that will be assumed by GitHub for OIDC.
    If set, the IAM role name for the repo will be exactly the variable value (64 characters max).

    Example: `{ "really-long-github-org-name/really-long-github-repo-name" = "custom-role-name" }`

    If unset, the default IAM role name for each repo will be
    `<aws_iam_role_prefix><aws_iam_role_separator><repo_owner><aws_iam_role_separator><repo_name>`,
    truncated to 64 characters.
  DESCRIPTION
  type        = map(string)
  default     = {}
  validation {
    condition     = alltrue([for key, value in var.aws_iam_role_names : length(value) <= 64])
    error_message = "The IAM role name must be less than or equal to 64 characters."
  }
}

variable "aws_iam_role_prefix" {
  description = "Prefix for name of IAM role that will be assumed by GitHub for OIDC"
  type        = string
  default     = "github-actions-oidc"
}

variable "aws_iam_role_separator" {
  description = "Character to use to separate words in name of IAM role"
  type        = string
  default     = "-"
}

variable "github_custom_claim" {
  description = <<-DESCRIPTION
    Custom OIDC claim for more specific access scope within the repository.
    The claim will be appended to the repo name, like "repo:repo-owner/repo-name:$${var.github_custom_claim}".
    For more details on what can be specified in this claim, see the
    [OIDC reference docs](https://docs.github.com/en/actions/reference/security/oidc) and
    [OIDC how-to for AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws).
  DESCRIPTION
  type        = string
  default     = "*"
}

variable "github_repos" {
  description = "Set of GitHub repositories to configure, in owner/repo format"
  type        = set(string)
}
