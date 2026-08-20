variable "region" {
  description = "Alibaba Cloud region for this stack. Cloud SSO has no cn-hangzhou endpoint; use one of cn-shanghai, cn-hongkong, ap-northeast-2, ap-southeast-1, us-west-1. Set in prod.tfvars."
  type        = string
  default     = ""

  validation {
    condition     = contains(["cn-shanghai", "cn-hongkong", "ap-northeast-2", "ap-southeast-1", "us-west-1"], var.region)
    error_message = "region must be set to a region with a Cloud SSO endpoint: cn-shanghai, cn-hongkong, ap-northeast-2, ap-southeast-1 or us-west-1."
  }
}

variable "spoke_role_arn" {
  description = "ARN of the management account SpokeDeployRole to assume (injected via TF_VAR_spoke_role_arn). Owns the Cloud SSO directory."
  type        = string

  validation {
    condition     = can(regex("^acs:ram::[0-9]{12,20}:role/[A-Za-z0-9_+=,.@-]+$", var.spoke_role_arn))
    error_message = "spoke_role_arn must be a RAM role ARN of the form acs:ram::<account-id>:role/<role-name>."
  }
}

variable "iam_role_arn" {
  description = "ARN of the SpokeDeployRole in the delegated-administrator iam account (injected via TF_VAR_iam_role_arn). Owns access configurations, users, groups and assignments."
  type        = string

  validation {
    condition     = can(regex("^acs:ram::[0-9]{12,20}:role/[A-Za-z0-9_+=,.@-]+$", var.iam_role_arn))
    error_message = "iam_role_arn must be a RAM role ARN of the form acs:ram::<account-id>:role/<role-name>."
  }
}

variable "directory_name" {
  description = "Cloud SSO directory name. Lowercase letters, digits and hyphens; cannot start or end with a hyphen or start with 'd-'. Set in prod.tfvars."
  type        = string
  default     = ""

  validation {
    condition = (
      length(var.directory_name) >= 2 &&
      length(var.directory_name) <= 64 &&
      can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.directory_name)) &&
      !can(regex("--", var.directory_name)) &&
      !can(regex("^d-", var.directory_name))
    )
    error_message = "directory_name must be set to 2-64 characters of lowercase letters, digits or hyphens, must not start or end with a hyphen, must not contain consecutive hyphens, and must not start with 'd-'."
  }
}

variable "login_preference" {
  description = "Portal login preferences for the directory. Defaults to withholding access-key issuance from portal users; prod.tfvars overrides."
  type = object({
    allow_user_to_get_credentials = optional(bool, false)
    login_network_masks           = optional(string)
  })
  default = {}

  validation {
    condition     = var.login_preference.login_network_masks == null || length(coalesce(var.login_preference.login_network_masks, "")) > 0
    error_message = "login_network_masks must be omitted or a non-empty newline-separated list of CIDR masks."
  }
}

variable "mfa_authentication_setting_info" {
  description = "Global MFA verification policy for the directory. Defaults to Enabled, which requires MFA on every login; prod.tfvars overrides."
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
  description = "Password policy for directory-local users. Defaults to a hardened baseline; prod.tfvars overrides."
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
  description = "Whether SCIM user provisioning is enabled on the directory. Defaults to disabled; prod.tfvars overrides."
  type        = bool
  default     = false
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
    condition = var.saml_identity_provider == null || alltrue([
      length(try(var.saml_identity_provider.entity_id, "")) > 0,
      length(try(var.saml_identity_provider.login_url, "")) > 0,
      length(try(var.saml_identity_provider.encoded_metadata_document, "")) > 0,
    ])
    error_message = "When saml_identity_provider is set, entity_id, login_url and encoded_metadata_document must all be non-empty."
  }

  validation {
    condition     = var.saml_identity_provider == null || contains(["Post", "Redirect"], try(var.saml_identity_provider.binding_type, "Post"))
    error_message = "binding_type must be either Post or Redirect."
  }

  validation {
    condition     = var.saml_identity_provider == null || contains(["Enabled", "Disabled"], try(var.saml_identity_provider.sso_status, "Enabled"))
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
  description = "Access configurations (permission sets) to create in the directory. Set in prod.tfvars."
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
  default = []

  validation {
    condition     = length(var.access_configurations) > 0
    error_message = "access_configurations must contain at least one access configuration; a directory without permission sets grants nobody access."
  }

  validation {
    condition = alltrue([
      for config in var.access_configurations :
      length(config.name) > 0 && length(config.name) <= 32 && can(regex("^[a-zA-Z0-9-]+$", config.name))
    ])
    error_message = "Each access configuration name must be 1-32 characters of letters, digits or hyphens."
  }

  validation {
    condition     = length(distinct([for config in var.access_configurations : config.name])) == length(var.access_configurations)
    error_message = "Access configuration names must be unique."
  }

  validation {
    condition = alltrue([
      for config in var.access_configurations :
      config.session_duration >= 900 && config.session_duration <= 43200
    ])
    error_message = "Each access configuration session_duration must be between 900 and 43200 seconds."
  }

  validation {
    condition = alltrue([
      for config in var.access_configurations :
      length(config.managed_system_policies) > 0 || config.inline_custom_policy != null
    ])
    error_message = "Each access configuration must grant at least one managed system policy or an inline custom policy."
  }

  validation {
    condition = alltrue([
      for config in var.access_configurations :
      config.inline_custom_policy == null || can(jsondecode(config.inline_custom_policy.policy_document))
    ])
    error_message = "Each inline_custom_policy.policy_document must be a valid JSON policy document."
  }
}

variable "groups" {
  description = "Directory groups and their members. Member names must exist in var.users. Set in prod.tfvars."
  type = list(object({
    group_name  = string
    description = optional(string)
    user_names  = optional(list(string), [])
  }))
  default = []

  validation {
    condition = alltrue([
      for group in var.groups :
      length(group.group_name) > 0 && length(group.group_name) <= 128 && can(regex("^[A-Za-z0-9._-]+$", group.group_name))
    ])
    error_message = "Each group_name must be 1-128 characters of letters, digits, dots, underscores or hyphens."
  }

  validation {
    condition     = length(distinct([for group in var.groups : group.group_name])) == length(var.groups)
    error_message = "Group names must be unique."
  }

  validation {
    condition = alltrue([
      for group in var.groups :
      length(distinct(group.user_names)) == length(group.user_names)
    ])
    error_message = "A group must not list the same user more than once."
  }
}

variable "users" {
  description = "Directory-local users. Passwords are intentionally omitted; users complete enrolment through the Cloud SSO portal. Set in prod.tfvars."
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
  default = []

  validation {
    condition = alltrue([
      for user in var.users :
      length(user.user_name) > 0 && length(user.user_name) <= 64 && can(regex("^[A-Za-z0-9._@-]+$", user.user_name))
    ])
    error_message = "Each user_name must be 1-64 characters of letters, digits, dots, underscores, at signs or hyphens."
  }

  validation {
    condition     = length(distinct([for user in var.users : user.user_name])) == length(var.users)
    error_message = "User names must be unique."
  }

  validation {
    condition = alltrue([
      for user in var.users :
      user.email == null || can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", coalesce(user.email, "")))
    ])
    error_message = "Each user email, when set, must be a valid address."
  }

  validation {
    condition = alltrue([
      for user in var.users :
      contains(["Enabled", "Disabled"], user.mfa_authentication_settings) && contains(["Enabled", "Disabled"], user.status)
    ])
    error_message = "Each user mfa_authentication_settings and status must be either Enabled or Disabled."
  }
}

variable "access_assignments" {
  description = "Assignments of access configurations to principals on target accounts. account_names are Resource Directory account display names. Set in prod.tfvars."
  type = list(object({
    principal_name             = string
    principal_type             = optional(string, "Group")
    account_names              = optional(list(string), [])
    include_management_account = optional(bool, false)
    access_configuration_names = list(string)
  }))
  default = []

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
      length(assignment.principal_name) > 0
    ])
    error_message = "Each assignment must name a principal."
  }

  validation {
    condition = alltrue([
      for assignment in var.access_assignments :
      length(assignment.access_configuration_names) > 0
    ])
    error_message = "Each assignment must reference at least one access configuration."
  }

  validation {
    condition = alltrue([
      for assignment in var.access_assignments :
      length(assignment.account_names) > 0 || assignment.include_management_account
    ])
    error_message = "Each assignment must target at least one account, either through account_names or include_management_account."
  }
}
