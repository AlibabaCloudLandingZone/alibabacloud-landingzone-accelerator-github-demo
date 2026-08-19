terraform {
  required_version = ">= 1.5"
  required_providers {
    alicloud = {
      source = "hashicorp/alicloud"
      # 1.279.0 introduces alicloud_ros_stack_instances, needed to target a
      # SERVICE_MANAGED stack group through deployment targets.
      version = ">= 1.279.0"
    }
  }
}
