# Management account provider (uses phase-0 operator credential from env).
provider "alicloud" {
  region = var.region
}

# One provider alias per spoke — chains via ResourceDirectoryAccountAccessRole.
provider "alicloud" {
  alias  = "log_archive"
  region = var.spokes["log-archive"].region
  assume_role {
    role_arn     = "acs:ram::${var.spokes["log-archive"].account_id}:role/ResourceDirectoryAccountAccessRole"
    session_name = "spoke-bootstrap"
  }
}

provider "alicloud" {
  alias  = "security"
  region = var.spokes["security"].region
  assume_role {
    role_arn     = "acs:ram::${var.spokes["security"].account_id}:role/ResourceDirectoryAccountAccessRole"
    session_name = "spoke-bootstrap"
  }
}

provider "alicloud" {
  alias  = "network"
  region = var.spokes["network"].region
  assume_role {
    role_arn     = "acs:ram::${var.spokes["network"].account_id}:role/ResourceDirectoryAccountAccessRole"
    session_name = "spoke-bootstrap"
  }
}

provider "alicloud" {
  alias  = "shared"
  region = var.spokes["shared"].region
  assume_role {
    role_arn     = "acs:ram::${var.spokes["shared"].account_id}:role/ResourceDirectoryAccountAccessRole"
    session_name = "spoke-bootstrap"
  }
}

provider "alicloud" {
  alias  = "devops"
  region = var.spokes["devops"].region
  assume_role {
    role_arn     = "acs:ram::${var.spokes["devops"].account_id}:role/ResourceDirectoryAccountAccessRole"
    session_name = "spoke-bootstrap"
  }
}
