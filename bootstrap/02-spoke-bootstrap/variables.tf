variable "region" {
  description = "Alibaba Cloud region"
  type        = string
  default     = "cn-hangzhou"
}

variable "hub_account_id" {
  description = "Account ID of the hub (CICD) account where the GitHub OIDC roles live"
  type        = string
}

variable "spokes" {
  description = "Map of spoke identifiers to their account ID and region"
  type = map(object({
    account_id = string
    region     = string
  }))
  default = {
    log-archive = { account_id = "REPLACE_ME", region = "cn-hangzhou" }
    security    = { account_id = "REPLACE_ME", region = "cn-hangzhou" }
    network     = { account_id = "REPLACE_ME", region = "cn-hangzhou" }
    shared      = { account_id = "REPLACE_ME", region = "cn-hangzhou" }
    devops      = { account_id = "REPLACE_ME", region = "cn-hangzhou" }
  }
}
