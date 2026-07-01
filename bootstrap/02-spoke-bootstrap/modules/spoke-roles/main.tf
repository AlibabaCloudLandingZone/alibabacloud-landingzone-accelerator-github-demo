# SpokePlanRole — trusted by hub's GitHubActionsPlanRole.
# Grants read-only access for terraform plan.
resource "alicloud_ram_role" "plan" {
  role_name            = "SpokePlanRole"
  max_session_duration = 3600
  assume_role_policy_document = jsonencode({
    Version = "1"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { RAM = ["acs:ram::${var.hub_account_id}:role/GitHubActionsPlanRole"] }
    }]
  })
}

resource "alicloud_ram_role_policy_attachment" "plan_readonly" {
  role_name   = alicloud_ram_role.plan.role_name
  policy_name = "ReadOnlyAccess"
  policy_type = "System"
}

# SpokeApplyRole — trusted by hub's GitHubActionsApplyRole.
# Grants admin access for terraform apply (scope down per spoke as appropriate).
resource "alicloud_ram_role" "apply" {
  role_name            = "SpokeApplyRole"
  max_session_duration = 3600
  assume_role_policy_document = jsonencode({
    Version = "1"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { RAM = ["acs:ram::${var.hub_account_id}:role/GitHubActionsApplyRole"] }
    }]
  })
}

resource "alicloud_ram_role_policy_attachment" "apply_admin" {
  role_name   = alicloud_ram_role.apply.role_name
  policy_name = "AdministratorAccess"
  policy_type = "System"
}
