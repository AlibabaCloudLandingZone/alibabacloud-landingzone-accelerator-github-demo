This repository relies on Terraform's native error handling and GitHub Actions workflow failure semantics for error management. There is no custom application code, so traditional error handling patterns (try/catch, custom error types, middleware) are not present.

### 1. System Approach
- **Terraform Native Errors**: Infrastructure provisioning errors are handled by the Terraform CLI. If a resource creation fails, Terraform halts execution and outputs the error message from the Alibaba Cloud API. State locking (via Tablestore) prevents concurrent state corruption errors.
- **CI/CD Failure Semantics**: GitHub Actions workflows are configured to fail fast. If any `terraform plan` or `terraform apply` step returns a non-zero exit code, the workflow job fails, notifying developers via the GitHub UI or PR checks.
- **OIDC Authentication Errors**: Authentication failures (e.g., expired tokens, incorrect role ARNs) are handled by the `aliyun/configure-aliyun-credentials-action`. If OIDC token exchange fails, the workflow step fails immediately.

### 2. Key Files
- `.github/workflows/terraform-reusable.yml`: Defines the reusable workflow steps. Failure in any step (Init, Plan, Apply) stops the pipeline.
- `.github/workflows/stacks.yml`: Orchestrates stack deployments. Uses `max-parallel: 1` for applies to prevent race conditions and cascading errors in shared resources.
- `bootstrap/01-cicd-foundation/main.tf`: Provisions the state locking mechanism (Tablestore) which mitigates state contention errors.

### 3. Architecture and Conventions
- **Plan vs. Apply**: Errors are caught early in the `plan` phase (triggered on PRs). The `apply` phase (triggered on merge) is protected by GitHub Environments (`production`) requiring manual approval, reducing the risk of erroneous changes reaching production.
- **State Management**: Remote state with locking ensures that concurrent operations do not result in inconsistent state files, a common source of hard-to-debug errors in Terraform.
- **No Custom Error Logic**: As an Infrastructure-as-Code repository, it delegates all error detection and reporting to the underlying tools (Terraform, Alibaba Cloud Provider, GitHub Actions).

### 4. Rules for Developers
- **Review Plans**: Always review the `terraform plan` output in PR comments to catch configuration errors before merging.
- **Check Workflow Logs**: If a workflow fails, inspect the specific step logs in GitHub Actions for the raw Terraform error message.
- **State Locking**: If a workflow fails unexpectedly and leaves a lock, manually unlock the state using `terraform force-unlock` only after confirming no other process is running.