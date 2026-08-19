# Management account: owns the Cloud SSO directory and service activation.
provider "alicloud" {
  region = var.region
  assume_role {
    role_arn           = var.spoke_role_arn
    session_name       = "tf-identity-cloudsso"
    session_expiration = 3600
  }
}

# Delegated administrator account: owns access configurations, principals and assignments.
provider "alicloud" {
  alias  = "iam"
  region = var.region
  assume_role {
    role_arn           = var.iam_role_arn
    session_name       = "tf-identity-cloudsso-iam"
    session_expiration = 3600
  }
}
