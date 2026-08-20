# Production variable values for 10-identity-cloudsso.
# Usage: terraform plan -var-file=prod.tfvars
#
# spoke_role_arn and iam_role_arn are injected by CI as TF_VAR_* and are not set here.

region = "cn-shanghai"

directory_name = "lz-prod-sso"

login_preference = {
  allow_user_to_get_credentials = true
}

mfa_authentication_setting_info = {
  mfa_authentication_advance_settings = "Enabled"
}

password_policy = {
  max_login_attempts            = 5
  max_password_age              = 90
  min_password_different_chars  = 4
  min_password_length           = 12
  password_not_contain_username = true
  password_reuse_prevention     = 3
}

scim_synchronization_enabled = true

# The credential secret is only returned at creation time, so it is generated in the console instead.
create_scim_server_credential = false

access_configurations = [
  {
    name                    = "Administrator"
    description             = "Full administrative access to the assigned account."
    managed_system_policies = ["AdministratorAccess"]
    session_duration        = 3600
  },
  {
    name                    = "ReadOnly"
    description             = "Read-only access for auditors and on-call responders."
    managed_system_policies = ["ReadOnlyAccess"]
    session_duration        = 14400
  },
  {
    name                    = "NetworkOps"
    description             = "Manage VPC and CEN resources in the network account."
    managed_system_policies = ["AliyunVPCFullAccess", "AliyunCENFullAccess"]
    session_duration        = 7200
  },
  {
    name                    = "SecurityAudit"
    description             = "Read-only plus audit-trail access for the security team."
    managed_system_policies = ["ReadOnlyAccess", "AliyunActionTrailReadOnlyAccess"]
    session_duration        = 14400
    inline_custom_policy = {
      policy_name     = "SlsAuditRead"
      policy_document = "{\"Version\":\"1\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"log:Get*\",\"log:List*\"],\"Resource\":[\"acs:log:*:*:project/*\"]}]}"
    }
  },
]

users = [
  {
    user_name    = "lz-admin"
    display_name = "Landing Zone Admin"
    email        = "lz-admin@example.com"
    description  = "Demo administrator account."
  },
  {
    user_name    = "lz-auditor"
    display_name = "Landing Zone Auditor"
    email        = "lz-auditor@example.com"
    description  = "Demo read-only account."
  },
]

groups = [
  {
    group_name  = "lz-admins"
    description = "Landing zone administrators."
    user_names  = ["lz-admin"]
  },
  {
    group_name  = "lz-readonly"
    description = "Landing zone read-only users."
    user_names  = ["lz-auditor"]
  },
  {
    group_name  = "lz-network-ops"
    description = "Network operations team."
  },
  {
    group_name  = "lz-security-audit"
    description = "Security audit team."
  },
]

access_assignments = [
  {
    principal_name             = "lz-admins"
    account_names              = ["devops", "log-archive", "security", "network", "shared-services", "iam"]
    include_management_account = true
    access_configuration_names = ["Administrator"]
  },
  {
    principal_name             = "lz-readonly"
    account_names              = ["devops", "log-archive", "security", "network", "shared-services", "iam"]
    access_configuration_names = ["ReadOnly"]
  },
  {
    principal_name             = "lz-network-ops"
    account_names              = ["network"]
    access_configuration_names = ["NetworkOps"]
  },
  {
    principal_name             = "lz-security-audit"
    account_names              = ["security", "log-archive"]
    access_configuration_names = ["SecurityAudit"]
  },
]
