output "plan_role_arn" {
  description = "ARN of the SpokePlanRole"
  value       = alicloud_ram_role.plan.arn
}

output "apply_role_arn" {
  description = "ARN of the SpokeApplyRole"
  value       = alicloud_ram_role.apply.arn
}
