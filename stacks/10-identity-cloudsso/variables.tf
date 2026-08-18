variable "region" {
  description = "Alibaba Cloud region for this stack. Cloud SSO has no cn-hangzhou endpoint; use one of cn-shanghai, cn-hongkong, ap-northeast-2, ap-southeast-1, us-west-1."
  type        = string
  default     = "cn-shanghai"
}

variable "spoke_role_arn" {
  description = "ARN of the management account SpokeDeployRole to assume (injected via TF_VAR_spoke_role_arn). Owns the Cloud SSO directory."
  type        = string
}

variable "iam_role_arn" {
  description = "ARN of the SpokeDeployRole in the delegated-administrator iam account (injected via TF_VAR_iam_role_arn). Owns access configurations, users, groups and assignments."
  type        = string
}

variable "directory_name" {
  description = "Cloud SSO directory name. Lowercase letters, digits and hyphens; cannot start or end with a hyphen or start with 'd-'."
  type        = string
  default     = "lz-prod-sso"

  validation {
    condition = (
      length(var.directory_name) >= 2 &&
      length(var.directory_name) <= 64 &&
      can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.directory_name)) &&
      !can(regex("--", var.directory_name)) &&
      !can(regex("^d-", var.directory_name))
    )
    error_message = "directory_name must be 2-64 characters of lowercase letters, digits or hyphens, must not start or end with a hyphen, must not contain consecutive hyphens, and must not start with 'd-'."
  }
}

variable "login_preference" {
  description = "Portal login preferences for the directory."
  type = object({
    allow_user_to_get_credentials = optional(bool, true)
    login_network_masks           = optional(string)
  })
  default = {}
}

variable "mfa_authentication_setting_info" {
  description = "Global MFA verification policy for the directory."
  type = object({
    mfa_authentication_advance_settings = optional(string, "Enabled")
    operation_for_risk_login            = optional(string)
  })
  default = {}

  validation {
    condition     = contains(["Enabled", "ByUser", "Disabled", "OnlyRiskyLogin"], var.mfa_authentication_setting_info.mfa_authentication_advance_settings)
    error_message = "mfa_authentication_advance_settings must be one of: Enabled, ByUser, Disabled, OnlyRiskyLogin."
  }

  validation {
    condition = (
      var.mfa_authentication_setting_info.operation_for_risk_login == null ||
      contains(["Autonomous", "EnforceVerify"], coalesce(var.mfa_authentication_setting_info.operation_for_risk_login, "Autonomous"))
    )
    error_message = "operation_for_risk_login must be either Autonomous or EnforceVerify."
  }
}

variable "password_policy" {
  description = "Password policy for directory-local users."
  type = object({
    max_login_attempts            = optional(number, 5)
    max_password_age              = optional(number, 90)
    min_password_different_chars  = optional(number, 4)
    min_password_length           = optional(number, 12)
    password_not_contain_username = optional(bool, true)
    password_reuse_prevention     = optional(number, 3)
  })
  default = {}

  validation {
    condition     = var.password_policy.min_password_length >= 8 && var.password_policy.min_password_length <= 32
    error_message = "min_password_length must be between 8 and 32."
  }

  validation {
    condition     = var.password_policy.max_login_attempts >= 0 && var.password_policy.max_login_attempts <= 32
    error_message = "max_login_attempts must be between 0 and 32 (0 means no limit)."
  }

  validation {
    condition     = var.password_policy.max_password_age >= 1 && var.password_policy.max_password_age <= 120
    error_message = "max_password_age must be between 1 and 120 days."
  }

  validation {
    condition     = var.password_policy.min_password_different_chars >= 0 && var.password_policy.min_password_different_chars <= var.password_policy.min_password_length
    error_message = "min_password_different_chars must be between 0 and min_password_length."
  }

  validation {
    condition     = var.password_policy.password_reuse_prevention >= 0 && var.password_policy.password_reuse_prevention <= 24
    error_message = "password_reuse_prevention must be between 0 and 24 (0 disables the check)."
  }
}

variable "scim_synchronization_enabled" {
  description = "Whether SCIM user provisioning is enabled on the directory."
  type        = bool
  default     = true
}

variable "create_scim_server_credential" {
  description = "Whether to create a SCIM server credential. The credential secret is only returned at creation time and cannot be recovered afterwards, so leave this off in CI and generate the credential in the console instead."
  type        = bool
  default     = false
}

variable "saml_identity_provider" {
  description = "External SAML identity provider configuration. Leave null until real IdP metadata is available; a placeholder metadata document is rejected by the API."
  type = object({
    entity_id                 = string
    login_url                 = string
    encoded_metadata_document = string
    binding_type              = optional(string, "Post")
    want_request_signed       = optional(bool, false)
    sso_status                = optional(string, "Enabled")
  })
  default = null

  validation {
    condition     = var.saml_identity_provider == null || contains(["Post", "Redirect"], var.saml_identity_provider.binding_type)
    error_message = "binding_type must be either Post or Redirect."
  }

  validation {
    condition     = var.saml_identity_provider == null || contains(["Enabled", "Disabled"], var.saml_identity_provider.sso_status)
    error_message = "sso_status must be either Enabled or Disabled."
  }
}

variable "saml_service_provider" {
  description = "Cloud SSO service-provider side SAML settings advertised to the IdP."
  type = object({
    authn_sign_algo             = optional(string)
    certificate_type            = optional(string)
    support_encrypted_assertion = optional(bool)
  })
  default = null
}

variable "access_configurations" {
  description = "Access configurations (permission sets) to create in the directory."
  type = list(object({
    name                    = string
    description             = optional(string)
    relay_state             = optional(string, "https://home.console.aliyun.com/")
    session_duration        = optional(number, 3600)
    managed_system_policies = optional(list(string), [])
    inline_custom_policy = optional(object({
      policy_name     = optional(string, "InlinePolicy")
      policy_document = string
    }))
  }))

  default = [
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

  validation {
    condition = alltrue([
      for config in var.access_configurations :
      length(config.name) > 0 && length(config.name) <= 32 && can(regex("^[a-zA-Z0-9-]+$", config.name))
    ])
    error_message = "Each access configuration name must be 1-32 characters of letters, digits or hyphens."
  }

  validation {
    condition = alltrue([
      for config in var.access_configurations :
      config.session_duration >= 900 && config.session_duration <= 43200
    ])
    error_message = "Each access configuration session_duration must be between 900 and 43200 seconds."
  }
}

variable "groups" {
  description = "Directory groups and their members. Member names must exist in var.users."
  type = list(object({
    group_name  = string
    description = optional(string)
    user_names  = optional(list(string), [])
  }))

  default = [
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
}

variable "users" {
  description = "Directory-local users. Passwords are intentionally omitted; users complete enrolment through the Cloud SSO portal."
  type = list(object({
    user_name                   = string
    display_name                = optional(string)
    description                 = optional(string)
    email                       = optional(string)
    first_name                  = optional(string)
    last_name                   = optional(string)
    mfa_authentication_settings = optional(string, "Enabled")
    status                      = optional(string, "Enabled")
    tags                        = optional(map(string), {})
  }))

  default = [
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
}

variable "access_assignments" {
  description = "Assignments of access configurations to principals on target accounts. account_names are Resource Directory account display names."
  type = list(object({
    principal_name             = string
    principal_type             = optional(string, "Group")
    account_names              = optional(list(string), [])
    include_management_account = optional(bool, false)
    access_configuration_names = list(string)
  }))

  default = [
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

  validation {
    condition = alltrue([
      for assignment in var.access_assignments :
      contains(["User", "Group"], assignment.principal_type)
    ])
    error_message = "Each principal_type must be either User or Group."
  }

  validation {
    condition = alltrue([
      for assignment in var.access_assignments :
      length(assignment.access_configuration_names) > 0
    ])
    error_message = "Each assignment must reference at least one access configuration."
  }
}
