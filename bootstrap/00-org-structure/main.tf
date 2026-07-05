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
