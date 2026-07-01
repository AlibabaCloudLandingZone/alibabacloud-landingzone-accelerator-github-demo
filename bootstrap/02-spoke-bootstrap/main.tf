# Deploy spoke roles into every member account.
# Each module call uses a different provider alias to target the spoke.

module "spoke_roles_log_archive" {
  source         = "./modules/spoke-roles"
  providers      = { alicloud = alicloud.log_archive }
  hub_account_id = var.hub_account_id
}

module "spoke_roles_security" {
  source         = "./modules/spoke-roles"
  providers      = { alicloud = alicloud.security }
  hub_account_id = var.hub_account_id
}

module "spoke_roles_network" {
  source         = "./modules/spoke-roles"
  providers      = { alicloud = alicloud.network }
  hub_account_id = var.hub_account_id
}

module "spoke_roles_shared" {
  source         = "./modules/spoke-roles"
  providers      = { alicloud = alicloud.shared }
  hub_account_id = var.hub_account_id
}

module "spoke_roles_devops" {
  source         = "./modules/spoke-roles"
  providers      = { alicloud = alicloud.devops }
  hub_account_id = var.hub_account_id
}
