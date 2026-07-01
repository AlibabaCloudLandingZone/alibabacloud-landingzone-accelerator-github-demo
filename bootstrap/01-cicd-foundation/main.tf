# =============================================================================
# 1. State infrastructure inside the CICD account
# =============================================================================

resource "alicloud_oss_bucket" "tfstate" {
  bucket        = "tfstate-${var.cicd_account_id}-${var.region}"
  storage_class = "Standard"

  versioning {
    status = "Enabled"
  }

  server_side_encryption_rule {
    sse_algorithm = "KMS"
  }

  lifecycle_rule {
    id      = "expire-old-versions"
    enabled = true
    noncurrent_version_expiration {
      days = 90
    }
  }
}

resource "alicloud_ots_instance" "tflock" {
  name          = "tfstate-lock"
  instance_type = "Capacity"
}

resource "alicloud_ots_table" "tflock" {
  instance_name = alicloud_ots_instance.tflock.name
  table_name    = "tflock"
  primary_key {
    name = "LockID"
    type = "String"
  }
  time_to_live = -1
  max_version  = 1
}

# =============================================================================
# 2. OIDC provider in the CICD account
# =============================================================================

resource "alicloud_ims_oidc_provider" "github" {
  oidc_provider_name  = "GitHubActions"
  issuer_url         = "https://token.actions.githubusercontent.com"
  client_ids         = ["sts.aliyuncs.com"]
  fingerprints       = ["22FF89586561FC2D52F77491E9F1EFF1B80BE33E"]
  issuance_limit_time = 12
  description        = "OIDC provider for GitHub Actions CI/CD"
}

# =============================================================================
# 3. Hub roles (plan + apply) in the CICD account
# =============================================================================

resource "alicloud_ram_role" "github_plan" {
  role_name            = "GitHubActionsPlanRole"
  max_session_duration = 3600
  assume_role_policy_document = jsonencode({
    Version = "1"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Federated = [alicloud_ims_oidc_provider.github.arn] }
      Condition = {
        StringEquals = {
          "oidc:aud" = "sts.aliyuncs.com"
          "oidc:iss" = "https://token.actions.githubusercontent.com"
        }
        StringLike = {
          "oidc:sub" = "repo:${var.github_org_repo}:pull_request"
        }
      }
    }]
  })
}

resource "alicloud_ram_role" "github_apply" {
  role_name            = "GitHubActionsApplyRole"
  max_session_duration = 3600
  assume_role_policy_document = jsonencode({
    Version = "1"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Federated = [alicloud_ims_oidc_provider.github.arn] }
      Condition = {
        StringEquals = {
          "oidc:aud" = "sts.aliyuncs.com"
          "oidc:iss" = "https://token.actions.githubusercontent.com"
        }
        StringLike = {
          "oidc:sub" = "repo:${var.github_org_repo}:environment:production"
        }
      }
    }]
  })
}

# =============================================================================
# 4. Hub role policies
#    Both roles need: OSS/OTS access to state infra + sts:AssumeRole on spokes
# =============================================================================

resource "alicloud_ram_policy" "hub_state_access" {
  policy_name = "HubStateAccess"
  policy_document = jsonencode({
    Version = "1"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["oss:GetObject", "oss:PutObject", "oss:DeleteObject", "oss:ListObjects", "oss:GetBucket"]
        Resource = ["acs:oss:*:*:${alicloud_oss_bucket.tfstate.bucket}", "acs:oss:*:*:${alicloud_oss_bucket.tfstate.bucket}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["ots:*"]
        Resource = ["*"]
      },
      {
        Effect   = "Allow"
        Action   = ["sts:AssumeRole"]
        Resource = ["acs:ram::*:role/SpokePlanRole", "acs:ram::*:role/SpokeApplyRole"]
      }
    ]
  })
}

resource "alicloud_ram_role_policy_attachment" "plan_state" {
  role_name   = alicloud_ram_role.github_plan.role_name
  policy_name = alicloud_ram_policy.hub_state_access.policy_name
  policy_type = "Custom"
}

resource "alicloud_ram_role_policy_attachment" "apply_state" {
  role_name   = alicloud_ram_role.github_apply.role_name
  policy_name = alicloud_ram_policy.hub_state_access.policy_name
  policy_type = "Custom"
}
