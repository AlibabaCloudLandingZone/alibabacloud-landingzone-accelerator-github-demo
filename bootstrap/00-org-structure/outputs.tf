output "resource_directory_id" {
  description = "Resource Directory ID"
  value       = module.folders.resource_directory_id
}

output "root_folder_id" {
  description = "Resource Directory root folder ID"
  value       = module.folders.root_folder_id
}

output "folder_ids" {
  description = "Map of folder names to their IDs"
  value       = { for f in module.folders.folder_structure : f.folder_name => f.id }
}

output "account_ids" {
  description = "Map of role names to account IDs"
  value       = module.accounts.role_to_account_mapping
}

output "spoke_deploy_role_arns" {
  description = "Map of account keys to their SpokeDeployRole ARNs (incl. management)"
  value = merge(
    { for k, id in module.accounts.role_to_account_mapping : k => "acs:ram::${id}:role/SpokeDeployRole" },
    { management = "acs:ram::${data.alicloud_account.current.id}:role/SpokeDeployRole" }
  )
}
