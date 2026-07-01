The project utilizes a **GitHub Actions**-based CI/CD pipeline to orchestrate the provisioning of an Alibaba Cloud Landing Zone using **Terraform**. The build system is designed around a "GitOps" model where infrastructure changes are driven by pull requests and merges to the `main` branch, leveraging **OIDC federation** for secure, credential-less authentication.

### Core Build Components
1. **Reusable Workflow**: `.github/workflows/terraform-reusable.yml` serves as the central engine for all Terraform operations. It accepts inputs for the working directory, action (`plan` or `apply`), and IAM roles, ensuring consistent execution across all stacks.
2. **Bootstrap Workflows**: Dedicated workflows (`bootstrap-00-org-structure.yml`, `bootstrap-01-cicd-foundation.yml`, `bootstrap-02-spoke.yml`) manage the initial phased setup of the cloud environment. These trigger on changes to their respective `bootstrap/` directories.
3. **Stacks Workflow**: `.github/workflows/stacks.yml` uses a **matrix strategy** to parallelize `plan` operations and sequentially execute `apply` operations for various infrastructure modules (Identity, Network, Security) located in the `stacks/` directory.

### Authentication & Security
- **OIDC Federation**: The pipeline uses `aliyun/configure-aliyun-credentials-action` to exchange GitHub OIDC tokens for short-lived Alibaba Cloud STS tokens. This eliminates the need for long-lived AccessKeys in repository secrets.
- **Role Chaining**: The workflow assumes a Hub Role in the CICD account, which then chains to Spoke Roles in target member accounts via the `TF_VAR_spoke_role_arn` environment variable.
- **Environment Protection**: The `apply` jobs are restricted to the `production` GitHub Environment, enabling manual approval gates before state-changing operations.

### State Management
- **Backend**: Terraform state is stored in **Alibaba Cloud OSS** with **Tablestore** for state locking, as defined in `backend.tf.example`.
- **Migration**: The build process includes a manual migration step (`terraform init -migrate-state`) to move local bootstrap state to the remote OSS backend after the CICD foundation is established.

### Developer Conventions
- **Path-Based Triggers**: Workflows are triggered only when files in specific directories change, optimizing CI runtime.
- **Plan Artifacts**: `terraform plan` output is uploaded as an artifact and commented on Pull Requests for review.
- **Version Pinning**: Terraform version is pinned to `1.9.5` in the workflows to ensure consistency.