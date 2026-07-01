variable "region" {
  description = "Alibaba Cloud region"
  type        = string
  default     = "cn-hangzhou"
}

variable "cicd_account_id" {
  description = "Account ID of the CICD/DevOps member account (from phase 1 output)"
  type        = string
}

variable "tfstate_bucket_name" {
  description = "Name of the OSS bucket for Terraform state storage"
  type        = string
}

variable "tfstate_lock_instance_name" {
  description = "Name of the Tablestore instance for Terraform state locking"
  type        = string
  default     = "tfstate-lock"
}

variable "github_org_repo" {
  description = "GitHub org/repo identifier, e.g. 'my-org/landing-zone'"
  type        = string
}
