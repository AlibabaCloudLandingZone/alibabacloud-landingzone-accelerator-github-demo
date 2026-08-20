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
data "alicloud_account" "current" {}

locals {
  hub_account_id       = module.accounts.role_to_account_mapping["devops"]
  spoke_roles_template = file("${path.module}/templates/spoke-roles.json")
}

# A SERVICE_MANAGED stack group cannot deploy into member accounts until ROS is
# a trusted service in the Resource Directory. No provider resource exposes that
# switch, so it is enabled through ROS itself.
resource "alicloud_ros_stack" "ros_trusted_service" {
  stack_name = "lza-ros-trusted-service"
  template_body = jsonencode({
    ROSTemplateFormatVersion = "2015-09-01"
    Description              = "Enables ROS as a trusted service in the Resource Directory."
    Resources = {
      EnableRosTrustedService = {
        Type = "ALIYUN::ROS::AutoEnableService"
        Properties = {
          ServiceName = "TrustedService/ROS"
        }
      }
    }
  })
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

  depends_on = [alicloud_ros_stack.ros_trusted_service]
}

resource "alicloud_ros_stack_instances" "spoke_roles" {
  stack_group_name = alicloud_ros_stack_group.spoke_roles.stack_group_name
  region_ids       = [var.region]

  # A SERVICE_MANAGED stack group only accepts deployment targets, never bare
  # account IDs, so this cannot use the singular alicloud_ros_stack_instance.
  # Targeting the root folder covers every member account in the Resource
  # Directory, so accounts added later pick up the role via auto_deployment
  # instead of needing this list refreshed.
  deployment_targets {
    rd_folder_ids = [module.folders.root_folder_id]
  }

  # The folder target no longer references the accounts, so the ordering the
  # old account_ids list provided has to be stated.
  depends_on = [module.accounts]
}
