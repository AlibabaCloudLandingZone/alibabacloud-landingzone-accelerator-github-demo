# 1. Enable Resource Directory on the current (management) account.
#    Idempotent — a no-op if RD is already enabled.
#    NOTE: `terraform destroy` will NOT disable RD; treat this resource
#    as a one-way switch.
resource "alicloud_resource_manager_resource_directory" "this" {}

data "alicloud_resource_manager_resource_directories" "this" {
  depends_on = [alicloud_resource_manager_resource_directory.this]
}

locals {
  root_folder_id = data.alicloud_resource_manager_resource_directories.this.directories[0].root_folder_id
}

# 2. Folder hierarchy
resource "alicloud_resource_manager_folder" "core" {
  folder_name      = "Core"
  parent_folder_id = local.root_folder_id
}

resource "alicloud_resource_manager_folder" "workloads" {
  folder_name      = "Workloads"
  parent_folder_id = local.root_folder_id
}

resource "alicloud_resource_manager_folder" "sandbox" {
  folder_name      = "Sandbox"
  parent_folder_id = local.root_folder_id
}

# 3. Core member accounts
locals {
  core_accounts = {
    devops          = { display_name = "devops", folder_id = alicloud_resource_manager_folder.core.id, billing_type = "Trusteeship" }
    log-archive     = { display_name = "log-archive", folder_id = alicloud_resource_manager_folder.core.id, billing_type = "Trusteeship" }
    security        = { display_name = "security", folder_id = alicloud_resource_manager_folder.core.id, billing_type = "Trusteeship" }
    network         = { display_name = "network", folder_id = alicloud_resource_manager_folder.core.id, billing_type = "Trusteeship" }
    shared-services = { display_name = "shared-services", folder_id = alicloud_resource_manager_folder.core.id, billing_type = "Trusteeship" }
  }
}

resource "alicloud_resource_manager_account" "core" {
  for_each = local.core_accounts

  display_name        = each.value.display_name
  folder_id           = each.value.folder_id
  account_name_prefix = each.value.display_name
  payer_account_id    = each.value.billing_type == "Trusteeship" ? data.alicloud_resource_manager_resource_directories.this.directories[0].master_account_id : null
}
