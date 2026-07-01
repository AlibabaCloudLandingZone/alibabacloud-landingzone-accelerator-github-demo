## Overview

This repository uses **Terraform's native dependency management system** to manage the Alibaba Cloud provider (`aliyun/alicloud`) across multiple modular stacks. Dependencies are declared in `versions.tf` files, pinned via `.terraform.lock.hcl` lockfiles, and initialized through CI/CD workflows using `hashicorp/setup-terraform`.

## Dependency Declaration System

### Provider Version Constraints

Every Terraform module (bootstrap phases and infrastructure stacks) declares its dependencies in a standardized `versions.tf` file:

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = ">= 1.262.1"
    }
  }
}
```

**Key conventions:**
- **Single provider**: All modules depend exclusively on `aliyun/alicloud` from the official Terraform Registry (`registry.terraform.io/aliyun/alicloud`).
- **Minimum version constraint**: Uses `>= 1.262.1` as a floor, allowing Terraform to resolve newer compatible versions during `init`.
- **Terraform CLI version**: Requires `>= 1.5`, which is the minimum version supporting OIDC-based authentication with the Alibaba Cloud provider.

### Lockfile-Based Pinning

Each module that has been initialized contains a `.terraform.lock.hcl` file that pins the exact provider version and includes cryptographic hashes for integrity verification:

```hcl
provider "registry.terraform.io/aliyun/alicloud" {
  version     = "1.280.0"
  constraints = ">= 1.262.1"
  hashes = [
    "h1:PQ6VflhtdW7tK6Cx0xVfVLFKf0gJDgPKqTeggf9H0OU=",
  ]
}
```

**Lockfile characteristics:**
- Automatically generated and maintained by `terraform init`.
- Pins the resolved version to `1.280.0` (consistent across all locked modules).
- Includes SHA-256 hash (`h1:` prefix) for provider binary verification.
- Present in bootstrap modules (`00-org-structure`, `01-cicd-foundation`, `02-spoke-bootstrap`) and some stack modules (`11-log-archive`, `20-network-cen`).
- **Not present** in several stack modules (e.g., `10-identity-cloudsso`, `12-guardrails-preventive`, `30-security-*`), indicating those stacks have not yet been initialized or their lockfiles are gitignored.

## CI/CD Dependency Resolution

### Terraform Setup in GitHub Actions

The reusable workflow (`.github/workflows/terraform-reusable.yml`) and stack workflow (`.github/workflows/stacks.yml`) use:

```yaml
- name: Setup Terraform
  uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: "1.9.5"
```

**CI dependency flow:**
1. `hashicorp/setup-terraform@v3` installs Terraform CLI version `1.9.5` (pinned in workflow inputs).
2. `terraform init -input=false` resolves provider dependencies based on `versions.tf` constraints.
3. If a `.terraform.lock.hcl` exists, Terraform uses the pinned version; otherwise, it resolves the latest compatible version within constraints.
4. Provider binaries are downloaded from `registry.terraform.io` and cached in `.terraform/providers/`.

### Provider Caching

The directory tree shows cached provider binaries at paths like:
```
.terraform/providers/registry.terraform.io/aliyun/alicloud/1.280.0/
```

These are local caches created during `terraform init` and should **not** be committed to version control (covered by `.gitignore`).

## Architecture and Conventions

### Modular Stack Structure

Dependencies are managed **per-module**, not centrally:
- Each bootstrap phase (`00-org-structure`, `01-cicd-foundation`, `02-spoke-bootstrap`) has its own `versions.tf` and `.terraform.lock.hcl`.
- Each infrastructure stack (`stacks/10-*`, `stacks/11-*`, etc.) has its own `versions.tf`.
- Reusable modules (e.g., `modules/spoke-roles/`) also declare their own `required_providers`.

This decentralized approach means:
- **Pros**: Each module can evolve independently; no single point of failure for dependency updates.
- **Cons**: Version drift risk — updating the provider in one module does not automatically update others.

### Backend Configuration Separation

Backend configuration (OSS + Tablestore for state locking) is declared in `versions.tf` for stacks that use remote state (e.g., `stacks/11-log-archive`), but bootstrap modules start with local backend and migrate to OSS after Phase 2. This separation ensures dependency resolution (`terraform init`) works correctly before and after state migration.

## Rules for Developers

### 1. Always Commit Lockfiles

When a module has been initialized and tested, commit its `.terraform.lock.hcl` to ensure reproducible builds:
```bash
terraform init
terraform plan  # validate
git add .terraform.lock.hcl
git commit -m "pin provider version"
```

### 2. Update Providers Deliberately

To upgrade the Alibaba Cloud provider across modules:
```bash
terraform init -upgrade
```
This re-resolves providers within the `>= 1.262.1` constraint and updates the lockfile. Test thoroughly before committing.

### 3. Keep Version Constraints Consistent

All modules currently use `>= 1.262.1`. When raising the minimum version (e.g., to access new provider features), update **all** `versions.tf` files consistently to avoid unexpected version divergence.

### 4. Never Commit `.terraform/` Directory

The `.terraform/` directory contains cached provider binaries and is excluded via `.gitignore`. Only commit `.terraform.lock.hcl`.

### 5. CI Uses Pinned Terraform CLI Version

The CI pipeline uses Terraform `1.9.5`. Ensure local development uses a compatible version (`>= 1.5` per `versions.tf`, but ideally match CI for consistency).

### 6. No Vendoring or Private Registries

The repository relies entirely on the public Terraform Registry (`registry.terraform.io`). There is no vendoring strategy, no `GOPRIVATE`-equivalent configuration, and no private registry setup. All provider downloads occur directly from HashiCorp's registry during `terraform init`.

## Key Files

| File | Purpose |
|------|---------|
| `bootstrap/*/versions.tf` | Declares provider constraints for bootstrap modules |
| `bootstrap/*/.terraform.lock.hcl` | Pins exact provider versions for bootstrap modules |
| `stacks/*/versions.tf` | Declares provider constraints for infrastructure stacks |
| `stacks/*/.terraform.lock.hcl` | Pins exact provider versions (where present) |
| `.github/workflows/terraform-reusable.yml` | CI workflow that runs `terraform init` to resolve dependencies |
| `.gitignore` | Excludes `.terraform/` cache directories |
