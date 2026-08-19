# Cloud SSO — directory, SAML/SCIM federation, access configurations, principals and assignments.
#
# The directory lives in the Resource Directory management account; everything else is managed from the
# `iam` member account, which bootstrap/00-org-structure already registers as the CloudSSO delegated
# administrator (alicloud_resource_manager_delegated_administrator for cloudsso.aliyuncs.com).
#
# The vendored LZA component (modules/lza/components/identity/cloudsso) covers the directory, access
# configurations, users, groups and assignments, but exposes no inputs for SAML federation or SCIM, which
# are inline attributes of the directory resource it owns. Those are required here, so the resources are
# declared directly.

data "alicloud_cloud_sso_service" "this" {
  enable = "On"
}

data "alicloud_account" "management" {}

data "alicloud_account" "iam" {
  provider = alicloud.iam
}

resource "alicloud_cloud_sso_directory" "this" {
  directory_name              = var.directory_name
  scim_synchronization_status = var.scim_synchronization_enabled ? "Enabled" : "Disabled"

  login_preference {
    allow_user_to_get_credentials = var.login_preference.allow_user_to_get_credentials
    login_network_masks           = var.login_preference.login_network_masks
  }

  mfa_authentication_setting_info {
    mfa_authentication_advance_settings = var.mfa_authentication_setting_info.mfa_authentication_advance_settings
    operation_for_risk_login            = var.mfa_authentication_setting_info.operation_for_risk_login
  }

  password_policy {
    max_login_attempts            = var.password_policy.max_login_attempts
    max_password_age              = var.password_policy.max_password_age
    min_password_different_chars  = var.password_policy.min_password_different_chars
    min_password_length           = var.password_policy.min_password_length
    password_not_contain_username = var.password_policy.password_not_contain_username
    password_reuse_prevention     = var.password_policy.password_reuse_prevention
  }

  dynamic "saml_identity_provider_configuration" {
    for_each = var.saml_identity_provider != null ? [var.saml_identity_provider] : []
    content {
      entity_id                 = saml_identity_provider_configuration.value.entity_id
      login_url                 = saml_identity_provider_configuration.value.login_url
      encoded_metadata_document = saml_identity_provider_configuration.value.encoded_metadata_document
      binding_type              = saml_identity_provider_configuration.value.binding_type
      want_request_signed       = saml_identity_provider_configuration.value.want_request_signed
      sso_status                = saml_identity_provider_configuration.value.sso_status
    }
  }

  dynamic "saml_service_provider" {
    for_each = var.saml_service_provider != null ? [var.saml_service_provider] : []
    content {
      authn_sign_algo             = saml_service_provider.value.authn_sign_algo
      certificate_type            = saml_service_provider.value.certificate_type
      support_encrypted_assertion = saml_service_provider.value.support_encrypted_assertion
    }
  }

  depends_on = [data.alicloud_cloud_sso_service.this]
}

# Hands day-to-day directory administration to the iam account. The Resource Directory registration is a
# prerequisite and is owned by bootstrap/00-org-structure.
resource "alicloud_cloud_sso_delegate_account" "this" {
  count      = data.alicloud_account.iam.id != data.alicloud_account.management.id ? 1 : 0
  account_id = data.alicloud_account.iam.id

  depends_on = [alicloud_cloud_sso_directory.this]
}

resource "alicloud_cloud_sso_scim_server_credential" "this" {
  provider = alicloud.iam
  count    = var.scim_synchronization_enabled && var.create_scim_server_credential ? 1 : 0

  directory_id = alicloud_cloud_sso_directory.this.id
  status       = "Enabled"

  depends_on = [alicloud_cloud_sso_delegate_account.this]
}

resource "alicloud_cloud_sso_access_configuration" "this" {
  provider = alicloud.iam
  for_each = { for config in var.access_configurations : config.name => config }

  directory_id              = alicloud_cloud_sso_directory.this.id
  access_configuration_name = each.value.name
  description               = each.value.description
  relay_state               = each.value.relay_state
  session_duration          = each.value.session_duration

  dynamic "permission_policies" {
    for_each = concat(
      [for policy in each.value.managed_system_policies : { type = "System", name = policy, document = null }],
      each.value.inline_custom_policy != null ? [{
        type     = "Inline"
        name     = each.value.inline_custom_policy.policy_name
        document = each.value.inline_custom_policy.policy_document
      }] : []
    )
    content {
      permission_policy_type     = permission_policies.value.type
      permission_policy_name     = permission_policies.value.name
      permission_policy_document = permission_policies.value.document
    }
  }

  depends_on = [alicloud_cloud_sso_delegate_account.this]
}

resource "alicloud_cloud_sso_user" "this" {
  provider = alicloud.iam
  for_each = { for user in var.users : user.user_name => user }

  directory_id                = alicloud_cloud_sso_directory.this.id
  user_name                   = each.value.user_name
  display_name                = each.value.display_name
  description                 = each.value.description
  email                       = each.value.email
  first_name                  = each.value.first_name
  last_name                   = each.value.last_name
  mfa_authentication_settings = each.value.mfa_authentication_settings
  status                      = each.value.status
  tags                        = each.value.tags

  depends_on = [alicloud_cloud_sso_delegate_account.this]
}

resource "alicloud_cloud_sso_group" "this" {
  provider = alicloud.iam
  for_each = { for group in var.groups : group.group_name => group }

  directory_id = alicloud_cloud_sso_directory.this.id
  group_name   = each.value.group_name
  description  = each.value.description

  depends_on = [alicloud_cloud_sso_delegate_account.this]
}

locals {
  group_memberships = {
    for membership in flatten([
      for group in var.groups : [
        for user_name in group.user_names : {
          group_name = group.group_name
          user_name  = user_name
        }
      ]
    ]) : "${membership.group_name}-${membership.user_name}" => membership
  }
}

resource "alicloud_cloud_sso_user_attachment" "this" {
  provider = alicloud.iam
  for_each = local.group_memberships

  directory_id = alicloud_cloud_sso_directory.this.id
  group_id     = alicloud_cloud_sso_group.this[each.value.group_name].group_id
  user_id      = alicloud_cloud_sso_user.this[each.value.user_name].user_id
}

data "alicloud_resource_manager_accounts" "this" {}

locals {
  account_ids_by_display_name = {
    for account in data.alicloud_resource_manager_accounts.this.accounts :
    account.display_name => account.id
  }

  principal_ids = merge(
    { for name, group in alicloud_cloud_sso_group.this : "Group-${name}" => group.group_id },
    { for name, user in alicloud_cloud_sso_user.this : "User-${name}" => user.user_id }
  )

  member_assignments = {
    for assignment in flatten([
      for item in var.access_assignments : [
        for account_name in item.account_names : [
          for config_name in item.access_configuration_names : {
            key                       = "${item.principal_type}-${item.principal_name}-${account_name}-${config_name}"
            principal_name            = item.principal_name
            principal_type            = item.principal_type
            account_name              = account_name
            access_configuration_name = config_name
          }
        ]
      ]
    ]) : assignment.key => assignment
  }

  management_assignments = {
    for assignment in flatten([
      for item in var.access_assignments : [
        for config_name in item.access_configuration_names : {
          key                       = "${item.principal_type}-${item.principal_name}-management-${config_name}"
          principal_name            = item.principal_name
          principal_type            = item.principal_type
          access_configuration_name = config_name
        }
      ] if item.include_management_account
    ]) : assignment.key => assignment
  }
}

resource "alicloud_cloud_sso_access_assignment" "member_accounts" {
  provider = alicloud.iam
  for_each = local.member_assignments

  directory_id            = alicloud_cloud_sso_directory.this.id
  access_configuration_id = alicloud_cloud_sso_access_configuration.this[each.value.access_configuration_name].access_configuration_id
  principal_id            = local.principal_ids["${each.value.principal_type}-${each.value.principal_name}"]
  principal_type          = each.value.principal_type
  target_id               = local.account_ids_by_display_name[each.value.account_name]
  target_type             = "RD-Account"
}

resource "alicloud_cloud_sso_access_assignment" "management_account" {
  for_each = local.management_assignments

  directory_id            = alicloud_cloud_sso_directory.this.id
  access_configuration_id = alicloud_cloud_sso_access_configuration.this[each.value.access_configuration_name].access_configuration_id
  principal_id            = local.principal_ids["${each.value.principal_type}-${each.value.principal_name}"]
  principal_type          = each.value.principal_type
  target_id               = data.alicloud_account.management.id
  target_type             = "RD-Account"
}
