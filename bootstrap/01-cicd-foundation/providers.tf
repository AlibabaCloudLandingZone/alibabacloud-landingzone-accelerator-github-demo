# During bootstrap: operator manually assumes role into the CICD account.
# After migration: the pipeline runs with CICD account credentials directly.
# In both cases the default provider targets the CICD account — no code change needed.
provider "alicloud" {
  region = var.region
}
# Provider for the management account (using phase-0 operator credential).
provider "alicloud" {
  alias  = "mgmt"
  region = var.region
}

# Chains from mgmt creds into the CICD account via ResourceDirectoryAccountAccessRole.
provider "alicloud" {
  alias  = "cicd"
  region = var.region
  assume_role {
    role_arn     = "acs:ram::${var.cicd_account_id}:role/ResourceDirectoryAccountAccessRole"
    session_name = "lz-bootstrap"
  }
}
