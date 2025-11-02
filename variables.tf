variable "aws_iam_role_names" {
  description = <<-DESCRIPTION
    Optional mapping of GitHub repos to names of IAM roles that will be assumed by GitHub for OIDC.

    If unset, a single IAM role will be provisioned for each repo with the name in the format
    `<aws_iam_role_prefix><aws_iam_role_separator><repo_owner><aws_iam_role_separator><repo_name>`,
    truncated to 64 characters.

    If set, IAM role names will be as provided, truncated to 64 characters (the max length enforced by IAM).
    Optionally, a list of custom claims can be provided for each role.
    For more details on what can be specified in these claims, see the
    [OIDC reference docs](https://docs.github.com/en/actions/reference/security/oidc) and
    [OIDC how-to for AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws).

    Examples:

    ```hcl
    aws_iam_role_names = {
      "really-long-github-org-name/really-long-github-repo-name" = "custom-role-name"
    }
    ```

    ```hcl
    aws_iam_role_names = {
      "really-long-github-org-name/really-long-github-repo-name" = {
        "read-only-role" = ["*"],
        "write-role"     = ["ref:refs/heads/main", "ref_type:tag"],
        "custom-role"    = ["*"],
      }
    }
    ```
  DESCRIPTION
  type        = map(any)
  default     = null
  validation {
    condition     = alltrue([for key, value in var.aws_iam_role_names : length(value) <= 64])
    error_message = "The IAM role name must be less than or equal to 64 characters."
  }
  validation {
    condition     = alltrue([for key, value in var.aws_iam_role_names : can(tostring(value)) || can(tomap(value))])
    error_message = "The IAM role names should be supplied as either a single string or a map."
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
