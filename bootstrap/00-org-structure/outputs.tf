output "root_folder_id" {
  description = "Resource Directory root folder ID"
  value       = local.root_folder_id
}

output "folder_ids" {
  description = "Map of folder names to their IDs"
  value = {
    Core      = alicloud_resource_manager_folder.core.id
    Workloads = alicloud_resource_manager_folder.workloads.id
    Sandbox   = alicloud_resource_manager_folder.sandbox.id
  }
}

output "account_ids" {
  description = "Map of account names to their IDs"
  value       = { for k, v in alicloud_resource_manager_account.core : k => v.id }
}
