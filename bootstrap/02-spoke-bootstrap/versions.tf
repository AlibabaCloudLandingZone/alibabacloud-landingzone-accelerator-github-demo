terraform {
  required_version = ">= 1.5"
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = ">= 1.262.1"
    }
  }
  # Initially local backend; migrate to OSS after phase 2 state infra is live.
}
