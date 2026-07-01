terraform {
  required_version = ">= 1.5"
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = ">= 1.262.1"
    }
  }
  # NO backend block — starts with local backend, migrated to OSS in phase 2
}
