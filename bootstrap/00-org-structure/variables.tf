variable "region" {
  description = "Alibaba Cloud region for the management account"
  type        = string
  default     = "cn-hangzhou"
}

variable "folder_structure" {
  description = "List of folders to create in the Resource Directory"
  type = list(object({
    folder_name        = string
    level              = number
    parent_folder_name = optional(string)
    tags               = optional(map(string), {})
  }))
  default = [
    { folder_name = "Core", level = 1 },
    { folder_name = "Workloads", level = 1 },
    { folder_name = "Sandbox", level = 1 },
  ]
}

variable "account_mapping" {
  description = "Map of role names to account configurations"
  type = map(object({
    account_name_prefix = string
    display_name        = string
    billing_type        = optional(string, "Trusteeship")
    billing_account_id  = optional(string)
    folder_id           = optional(string)
    tags                = optional(map(string), {})
  }))
  default = {
    devops          = { account_name_prefix = "devops", display_name = "devops", billing_type = "Trusteeship" }
    log             = { account_name_prefix = "log-archive", display_name = "log-archive", billing_type = "Trusteeship" }
    security        = { account_name_prefix = "security", display_name = "security", billing_type = "Trusteeship" }
    network         = { account_name_prefix = "network", display_name = "network", billing_type = "Trusteeship" }
    shared_services = { account_name_prefix = "shared-services", display_name = "shared-services", billing_type = "Trusteeship" }
    iam             = { account_name_prefix = "iam", display_name = "iam", billing_type = "Trusteeship" }
  }
}
