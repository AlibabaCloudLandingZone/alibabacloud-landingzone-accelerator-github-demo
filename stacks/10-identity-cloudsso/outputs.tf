output "directory_id" {
  description = "ID of the Cloud SSO directory"
  value       = alicloud_cloud_sso_directory.this.id
}

output "directory_name" {
  description = "Name of the Cloud SSO directory"
  value       = alicloud_cloud_sso_directory.this.directory_name
}

output "scim_synchronization_status" {
  description = "SCIM synchronization status of the directory"
  value       = alicloud_cloud_sso_directory.this.scim_synchronization_status
}

output "saml_service_provider" {
  description = "Cloud SSO service-provider metadata (ACS URL, entity ID, SP metadata document) needed to register the directory with an external IdP"
  value       = alicloud_cloud_sso_directory.this.saml_service_provider
}

output "delegated_admin_account_id" {
  description = "Account ID administering the directory, empty when the management account administers it directly"
  value       = try(alicloud_cloud_sso_delegate_account.this[0].account_id, "")
}

output "access_configuration_ids" {
  description = "Map of access configuration names to their IDs"
  value       = { for name, config in alicloud_cloud_sso_access_configuration.this : name => config.access_configuration_id }
}

output "group_ids" {
  description = "Map of group names to their IDs"
  value       = { for name, group in alicloud_cloud_sso_group.this : name => group.group_id }
}

output "user_ids" {
  description = "Map of user names to their IDs"
  value       = { for name, user in alicloud_cloud_sso_user.this : name => user.user_id }
}

output "access_assignment_ids" {
  description = "IDs of all access assignments"
  value = concat(
    [for assignment in alicloud_cloud_sso_access_assignment.member_accounts : assignment.id],
    [for assignment in alicloud_cloud_sso_access_assignment.management_account : assignment.id]
  )
}
