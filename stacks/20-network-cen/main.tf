# CEN (Cloud Enterprise Network) — hub-and-spoke network topology.
#
# This stack deploys into the network spoke account.
# In production, source from the vendored LZA module:
#   module "cen" {
#     source = "../../modules/lza/components/network/cen-instance"
#     ...
#   }
#
# For this demo, we define the core CEN resource directly.

resource "alicloud_cen_instance" "this" {
  cen_instance_name = var.cen_name
  description       = "Landing Zone production CEN"
}
