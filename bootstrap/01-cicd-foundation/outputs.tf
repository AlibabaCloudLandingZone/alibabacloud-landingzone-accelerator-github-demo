output "tfstate_bucket" {
  description = "OSS bucket for Terraform state"
  value       = alicloud_oss_bucket.tfstate.bucket
}

output "tfstate_tablestore_endpoint" {
  description = "Tablestore endpoint for state locking"
  value       = "https://${alicloud_ots_instance.tflock.name}.${var.region}.ots.aliyuncs.com"
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider"
  value       = alicloud_ims_oidc_provider.github.arn
}

output "github_plan_role_arn" {
  description = "ARN of the GitHubActionsPlanRole (hub)"
  value       = alicloud_ram_role.github_plan.arn
}

output "github_apply_role_arn" {
  description = "ARN of the GitHubActionsApplyRole (hub)"
  value       = alicloud_ram_role.github_apply.arn
}
