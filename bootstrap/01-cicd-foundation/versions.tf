terraform {
  required_version = ">= 1.5"
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = ">= 1.262.1"
    }
  }
  # NO backend block initially — migrate to OSS after apply.
  # See backend.tf.example for the post-migration configuration.
}
