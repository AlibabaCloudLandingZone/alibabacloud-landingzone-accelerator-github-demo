terraform {
  required_version = ">= 1.5"
  required_providers {
    alicloud = {
      source  = "hashicorp/alicloud"
      version = ">= 1.267.0"
    }
  }
  # NO backend block — starts with local backend, migrated to OSS in phase 2
}
