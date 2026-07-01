The repository employs a **Infrastructure-as-Code (IaC) configuration system** driven by **Terraform** and orchestrated via **GitHub Actions**. There is no traditional application configuration (e.g., `.env`, `config.yaml` for app runtime); instead, "configuration" refers to the provisioning parameters for cloud infrastructure.

### 1. Configuration Sources & Layering
The system uses a multi-layered approach to manage infrastructure state and parameters:

*   **GitHub Repository Variables**: The primary source of dynamic, environment-specific configuration. Key variables include:
    *   `HUB_ACCOUNT_ID`: The central CI/CD account ID.
    *   `GHA_PLAN_ROLE_ARN` / `GHA_APPLY_ROLE_ARN`: IAM roles for OIDC federation.
    *   `OIDC_PROVIDER_ARN`: The Alibaba Cloud OIDC provider ARN.
    *   `SPOKE_ACCOUNT_IDS_JSON`: A JSON map linking logical account keys (e.g., `devops`, `network`) to actual Alibaba Cloud Account IDs. This allows the same Terraform code to be deployed across different accounts by simply changing the input variable.
*   **Terraform Variables (`variables.tf`)**: Each module defines its own schema for required inputs. Defaults are provided for stable values (e.g., `region = "cn-hangzhou"`), while sensitive or environment-specific values (like `spoke_role_arn`) are injected at runtime.
*   **Environment Variables (`TF_VAR_*`)**: GitHub Actions workflows inject specific Terraform variables using the `TF_VAR_` prefix convention. For example, `TF_VAR_spoke_role_arn` is dynamically constructed in the workflow using the `SPOKE_ACCOUNT_IDS_JSON` variable and passed to the Terraform process.
*   **Backend Configuration**: State backend details (OSS bucket, Tablestore endpoint) are managed via `backend.tf` files. A `backend.tf.example` is provided to guide users in migrating from local state to the remote OSS backend after the initial bootstrap phase.

### 2. Key Files & Packages
*   **`.github/workflows/stacks.yml`**: The central orchestration file for day-2 operations. It uses a **matrix strategy** to deploy multiple stacks (identity, network, security) in parallel or sequence, mapping each stack to a specific spoke account via `SPOKE_ACCOUNT_IDS_JSON`.
*   **`.github/workflows/terraform-reusable.yml`**: A reusable workflow that encapsulates the standard Terraform lifecycle (init, plan, apply). It accepts inputs for the working directory, role ARNs, and action type, ensuring consistent execution across all stacks.
*   **`bootstrap/*/variables.tf`**: Define the input schema for the initial setup phases (Org Structure, CI/CD Foundation, Spoke Bootstrap).
*   **`stacks/*/variables.tf`**: Define inputs for individual infrastructure domains (e.g., `spoke_role_arn`, `cen_name`).

### 3. Architecture & Conventions
*   **OIDC Federation**: The system eliminates long-lived credentials by using GitHub Actions OIDC tokens to assume Alibaba Cloud RAM roles. This is configured in the workflows using the `aliyun/configure-aliyun-credentials-action`.
*   **Spoke-Role Assumption Pattern**: The CI/CD pipeline assumes a "Hub Role" in the CICD account, which then assumes a "Spoke Role" in the target member account. This cross-account trust model is configured via the `spoke_role_arn` variable.
*   **State Management**: Terraform state is stored in Alibaba Cloud OSS with KMS encryption and locked via Tablestore. This is configured in the `backend` block of each stack.
*   **Modular Stacks**: Infrastructure is divided into logical stacks (e.g., `10-identity-cloudsso`, `20-network-cen`). Each stack is a self-contained Terraform module with its own `variables.tf`, `main.tf`, and `providers.tf`.

### 4. Rules for Developers
*   **No Hardcoded Secrets**: Never hardcode Account IDs, ARNs, or AccessKeys in Terraform files. Use GitHub Repository Variables or Terraform variables.
*   **Use `TF_VAR_` for Injection**: When passing dynamic values from GitHub Actions to Terraform, use the `TF_VAR_<variable_name>` environment variable convention.
*   **Matrix Configuration**: To add a new stack, update the `matrix` in `.github/workflows/stacks.yml` and ensure the corresponding account key exists in `SPOKE_ACCOUNT_IDS_JSON`.
*   **Backend Migration**: For bootstrap stacks, follow the `backend.tf.example` instructions to migrate state to OSS after the initial local apply.
*   **Least Privilege**: Use `GHA_PLAN_ROLE_ARN` for PR checks (read-only) and `GHA_APPLY_ROLE_ARN` for merges (read-write), enforced by GitHub Environments.