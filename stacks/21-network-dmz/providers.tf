provider "alicloud" {
  region = var.region
  assume_role {
    role_arn           = var.spoke_role_arn
    session_name       = "tf-network-dmz"
    session_expiration = 3600
  }
}
