variable "aws_provider_region" {
  description = "AWS region to use when configuring AWS Terraform provider"
  type        = string
  default     = "us-east-1"
}

variable "github_repos" {
  description = "Set of GitHub repositories to configure, in owner/repo format"
  type        = set(string)
}
