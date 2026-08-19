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
#    Deployed into every member account via a SERVICE_MANAGED ROS stack group,
#    and into the management account via a plain ROS stack reusing the same
#    template. A single role serves both plan and apply because alicloud
#    provider data sources activate services, which exceeds ReadOnlyAccess.
#    Role ARN is deterministic: acs:ram::<account_id>:role/SpokeDeployRole
#    Precondition: ROS trusted access must be enabled in the Resource Directory.
data "alicloud_account" "current" {}

locals {
  hub_account_id       = module.accounts.role_to_account_mapping["devops"]
  spoke_roles_template = file("${path.module}/templates/spoke-roles.json")
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

resource "alicloud_ros_stack" "spoke_roles_management" {
  stack_name    = "lza-spoke-roles"
  template_body = local.spoke_roles_template

  parameters {
    parameter_key   = "HubAccountId"
    parameter_value = local.hub_account_id
  }
}
