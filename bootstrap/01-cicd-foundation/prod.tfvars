# Production variable values for 01-cicd-foundation.
# Usage: terraform plan -var-file=prod.tfvars
#
# CI passes this file too, via the var_file input of terraform-reusable.yml.
# cicd_account_id, tfstate_bucket_name and github_org_repo have no defaults, so
# renaming or removing this file breaks both local runs and the pipeline.

region = "cn-hangzhou"

cicd_account_id = "1328983224613218"

tfstate_bucket_name = "lza-tfstate-1328983224613218"

tfstate_lock_instance_name = "tflock-1328983"

github_org_repo = "AlibabaCloudLandingZone/alibabacloud-landingzone-accelerator-github-demo"
