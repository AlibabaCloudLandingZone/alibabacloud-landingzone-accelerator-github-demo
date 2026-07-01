terraform {
  required_version = ">= 1.5"
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = ">= 1.262.1"
    }
  }
  backend "oss" {
    bucket              = "tfstate-<CICD_ACCOUNT_ID>-cn-hangzhou"
    prefix              = "stacks/10-identity-cloudsso"
    key                 = "terraform.tfstate"
    region              = "cn-hangzhou"
    tablestore_endpoint = "https://tfstate-lock.cn-hangzhou.ots.aliyuncs.com"
    tablestore_table    = "tflock"
  }
}
