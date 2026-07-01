# =============================================================================
# 0. Pre-flight checks and service activation
# =============================================================================

data "alicloud_account" "current" {}

resource "terraform_data" "account_id_check" {
  lifecycle {
    precondition {
      condition     = data.alicloud_account.current.id == var.cicd_account_id
      error_message = "SAFETY CHECK FAILED: Current account (${data.alicloud_account.current.id}) does not match the expected CICD account (${var.cicd_account_id}). Ensure you have assumed role into the correct account."
    }
  }
}

data "alicloud_oss_service" "open" {
  enable = "On"
}

# =============================================================================
# 1. State infrastructure inside the CICD account
# =============================================================================

locals {
  tfstate_bucket_name = var.tfstate_bucket_name
}

resource "alicloud_oss_bucket" "tfstate" {
  depends_on    = [data.alicloud_oss_service.open]
  bucket        = local.tfstate_bucket_name
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
  name          = var.tfstate_lock_instance_name
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
#    Plan role: read state + assume SpokePlanRole
#    Apply role: read/write state + assume SpokeApplyRole
# =============================================================================

resource "alicloud_ram_policy" "hub_chain_plan" {
  policy_name = "HubChainPlan"
  policy_document = jsonencode({
    Version = "1"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = ["acs:ram::*:role/SpokePlanRole"]
      },
      {
        Effect   = "Allow"
        Action   = ["oss:GetObject", "oss:ListObjects", "oss:GetBucketInfo"]
        Resource = ["acs:oss:*:*:${alicloud_oss_bucket.tfstate.bucket}", "acs:oss:*:*:${alicloud_oss_bucket.tfstate.bucket}/*"]
      },
      {
        Effect   = "Allow"
        Action   = "ots:*"
        Resource = ["acs:ots:*:*:instance/${alicloud_ots_instance.tflock.name}", "acs:ots:*:*:instance/${alicloud_ots_instance.tflock.name}/*"]
      }
    ]
  })
}

resource "alicloud_ram_policy" "hub_chain_apply" {
  policy_name = "HubChainApply"
  policy_document = jsonencode({
    Version = "1"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = ["acs:ram::*:role/SpokeApplyRole"]
      },
      {
        Effect   = "Allow"
        Action   = ["oss:GetObject", "oss:ListObjects", "oss:GetBucketInfo", "oss:PutObject", "oss:DeleteObject"]
        Resource = ["acs:oss:*:*:${alicloud_oss_bucket.tfstate.bucket}", "acs:oss:*:*:${alicloud_oss_bucket.tfstate.bucket}/*"]
      },
      {
        Effect   = "Allow"
        Action   = "ots:*"
        Resource = ["acs:ots:*:*:instance/${alicloud_ots_instance.tflock.name}", "acs:ots:*:*:instance/${alicloud_ots_instance.tflock.name}/*"]
      }
    ]
  })
}

resource "alicloud_ram_role_policy_attachment" "plan" {
  role_name   = alicloud_ram_role.github_plan.role_name
  policy_name = alicloud_ram_policy.hub_chain_plan.policy_name
  policy_type = "Custom"
}

resource "alicloud_ram_role_policy_attachment" "apply" {
  role_name   = alicloud_ram_role.github_apply.role_name
  policy_name = alicloud_ram_policy.hub_chain_apply.policy_name
  policy_type = "Custom"
}
