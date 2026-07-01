variable "region" {
  description = "Alibaba Cloud region"
  type        = string
  default     = "cn-hangzhou"
}

variable "cicd_account_id" {
  description = "Account ID of the CICD/DevOps member account (from phase 1 output)"
  type        = string
}

variable "github_org_repo" {
  description = "GitHub org/repo identifier, e.g. 'my-org/landing-zone'"
  type        = string
}
