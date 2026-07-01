variable "region" {
  description = "Alibaba Cloud region for this stack"
  type        = string
  default     = "cn-hangzhou"
}

variable "spoke_role_arn" {
  description = "ARN of the spoke role to assume (injected via TF_VAR_spoke_role_arn)"
  type        = string
}

variable "cen_name" {
  description = "Name for the CEN instance"
  type        = string
  default     = "lz-prod-cen"
}
