# Locally the operator's management-account credentials are used directly
# (ALICLOUD_ACCESS_KEY / ALICLOUD_SECRET_KEY). In CI the ambient credentials are
# the hub role in the CICD account, so management_role_arn is set and the
# provider chains into the management account's SpokeDeployRole.
provider "alicloud" {
  region = var.region

  dynamic "assume_role" {
    for_each = var.management_role_arn != "" ? [var.management_role_arn] : []
    content {
      role_arn           = assume_role.value
      session_name       = "tf-org-structure"
      session_expiration = 3600
    }
  }
}
