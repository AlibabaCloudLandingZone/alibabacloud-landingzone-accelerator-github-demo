output "spoke_plan_role_arns" {
  description = "Map of spoke names to their SpokePlanRole ARNs"
  value = {
    log-archive = module.spoke_roles_log_archive.plan_role_arn
    security    = module.spoke_roles_security.plan_role_arn
    network     = module.spoke_roles_network.plan_role_arn
    shared      = module.spoke_roles_shared.plan_role_arn
    devops      = module.spoke_roles_devops.plan_role_arn
  }
}

output "spoke_apply_role_arns" {
  description = "Map of spoke names to their SpokeApplyRole ARNs"
  value = {
    log-archive = module.spoke_roles_log_archive.apply_role_arn
    security    = module.spoke_roles_security.apply_role_arn
    network     = module.spoke_roles_network.apply_role_arn
    shared      = module.spoke_roles_shared.apply_role_arn
    devops      = module.spoke_roles_devops.apply_role_arn
  }
}
