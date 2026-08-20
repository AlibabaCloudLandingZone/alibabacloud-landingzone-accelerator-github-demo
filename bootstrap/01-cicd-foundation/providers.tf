# Locally the operator assumes into the CICD account and runs with those
# credentials directly. In CI the ambient credentials are the hub role, which
# only carries state access, so spoke_role_arn is set and the provider chains
# into the CICD account's SpokeDeployRole.
provider "alicloud" {
  region = var.region

  dynamic "assume_role" {
    for_each = var.spoke_role_arn != "" ? [var.spoke_role_arn] : []
    content {
      role_arn           = assume_role.value
      session_name       = "tf-cicd-foundation"
      session_expiration = 3600
    }
  }
}
