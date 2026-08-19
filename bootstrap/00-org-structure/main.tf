# 1. Resource Directory + Folder Hierarchy
#    Creates the Resource Directory (if not already enabled) and the folder
#    structure defined in var.folder_structure.
module "folders" {
  source = "../../modules/lza/components/resource-structure/folders"

  use_existing_resource_directory = false
  folder_structure                = var.folder_structure
}

# 2. Core Member Accounts
#    Creates member accounts in the "Core" folder as defined in var.account_mapping.
#    Each account gets a ResourceDirectoryAccountAccessRole that allows the
#    management account to assume into it for subsequent bootstrap phases.
module "accounts" {
  source = "../../modules/lza/components/resource-structure/accounts"

  resource_directory_id = module.folders.resource_directory_id
  default_folder_id     = [for f in module.folders.folder_structure : f.id if f.folder_name == "Core"][0]
  account_mapping       = var.account_mapping
  delegated_services = {
    "cloudsso.aliyuncs.com" = ["iam"]
  }
}

# 3. Spoke Role (SpokeDeployRole)
#    Deployed into every member account via a SERVICE_MANAGED ROS stack group.
#    A single role serves both plan and apply because alicloud provider data
#    sources activate services, which exceeds ReadOnlyAccess.
#    Role ARN is deterministic: acs:ram::<account_id>:role/SpokeDeployRole
#    The management account's copy cannot come from ROS: CI has to assume it
#    before it can run this stage at all. It is created once by hand and then
#    imported into the two resources below — see README "Seeding the management
#    role" — so the trust policy stays in code from then on.
#    Precondition: ROS trusted access must be enabled in the Resource Directory.
data "alicloud_account" "current" {}

locals {
  hub_account_id       = module.accounts.role_to_account_mapping["devops"]
  spoke_roles_template = file("${path.module}/templates/spoke-roles.json")
}

resource "alicloud_ram_role" "spoke_deploy_management" {
  name                 = "SpokeDeployRole"
  description          = "Role assumed by the hub GitHubActions roles for terraform plan and apply."
  max_session_duration = 3600
  document = jsonencode({
    Version = "1"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        # RAM stores principal ARNs lowercased; matching that avoids a permanent diff.
        RAM = [
          lower("acs:ram::${local.hub_account_id}:role/GitHubActionsPlanRole"),
          lower("acs:ram::${local.hub_account_id}:role/GitHubActionsApplyRole"),
        ]
      }
    }]
  })
}

resource "alicloud_ram_role_policy_attachment" "spoke_deploy_management" {
  role_name   = alicloud_ram_role.spoke_deploy_management.name
  policy_name = "AdministratorAccess"
  policy_type = "System"
}

resource "alicloud_ros_stack_group" "spoke_roles" {
  stack_group_name = "lza-spoke-roles"
  description      = "SpokeDeployRole for landing zone CI/CD"
  template_body    = local.spoke_roles_template
  permission_model = "SERVICE_MANAGED"

  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }

  parameters {
    parameter_key   = "HubAccountId"
    parameter_value = local.hub_account_id
  }
}

resource "alicloud_ros_stack_instance" "spoke_roles" {
  for_each = module.accounts.role_to_account_mapping

  stack_group_name          = alicloud_ros_stack_group.spoke_roles.stack_group_name
  stack_instance_account_id = each.value
  stack_instance_region_id  = var.region
  retain_stacks             = false
}
