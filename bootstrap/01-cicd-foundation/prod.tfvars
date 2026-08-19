# Production variable values for 01-cicd-foundation.
# Usage: terraform plan -var-file=prod.tfvars

region = "cn-hangzhou"

cicd_account_id = "1328983224613218"

tfstate_bucket_name = "lza-tfstate-1328983224613218"

tfstate_lock_instance_name = "tflock-1328983"

github_org_repo = "AlibabaCloudLandingZone/alibabacloud-landingzone-accelerator-github-demo"
