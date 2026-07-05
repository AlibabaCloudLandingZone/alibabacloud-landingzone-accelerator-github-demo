# Production variable values for 00-org-structure.
# Usage: terraform plan -var-file=prod.tfvars

region = "cn-hangzhou"

folder_structure = [
  { folder_name = "Core", level = 1 },
  { folder_name = "Workloads", level = 1 },
  { folder_name = "Sandbox", level = 1 },
]

account_mapping = {
  devops = {
    account_name_prefix = "devops"
    display_name        = "devops"
    billing_type        = "Trusteeship"
  }
  log = {
    account_name_prefix = "log-archive"
    display_name        = "log-archive"
    billing_type        = "Trusteeship"
  }
  security = {
    account_name_prefix = "security"
    display_name        = "security"
    billing_type        = "Trusteeship"
  }
  network = {
    account_name_prefix = "network"
    display_name        = "network"
    billing_type        = "Trusteeship"
  }
  shared_services = {
    account_name_prefix = "shared-services"
    display_name        = "shared-services"
    billing_type        = "Trusteeship"
  }
  iam = {
    account_name_prefix = "iam"
    display_name        = "iam"
    billing_type        = "Trusteeship"
  }
}
