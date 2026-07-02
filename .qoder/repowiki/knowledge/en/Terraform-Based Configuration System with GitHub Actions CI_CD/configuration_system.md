This repository implements a configuration system built entirely on Terraform for Alibaba Cloud Landing Zone infrastructure. The configuration approach follows a three-phase bootstrap pattern combined with modular stack deployment through GitHub Actions workflows.

**Configuration Architecture:**
- **Three-phase bootstrap**: `bootstrap/00-org-structure`, `bootstrap/01-cicd-foundation`, and `bootstrap/02-spoke-bootstrap` progressively establish the organization structure, CI/CD foundation with OIDC state management, and spoke account roles respectively
- **Modular stack deployment**: `stacks/` directory contains numbered Terraform stacks (identity, logging, guardrails, networking, security) that compose reusable modules from `modules/lza/components/` and `modules/lza/modules/`
- **Variable-driven configuration**: Each Terraform module uses `variables.tf` files to define configurable parameters, with environment-specific values passed through GitHub Actions workflow inputs and job variables
- **Backend configuration**: State is managed via remote backends configured in `backend.tf.example` files, supporting different environments through separate backend configurations

**Key Configuration Patterns:**
- **Module composition**: Stacks act as thin composition layers that call into reusable components and modules, keeping configuration concerns separated from implementation
- **Environment isolation**: Each bootstrap phase and stack operates independently with its own state, providers, and variable definitions
- **GitHub Actions integration**: Workflows in `.github/workflows/` orchestrate the configuration lifecycle, passing secrets and variables to Terraform runs without long-lived credentials
- **Version pinning**: Provider versions are explicitly pinned in `versions.tf` files for reproducibility

**Configuration Files Structure:**
- `main.tf`: Primary resource declarations per stack/module
- `variables.tf`: Input parameter definitions with types and defaults
- `outputs.tf`: Exported values consumed by other stacks or workflows
- `providers.tf`: Provider configuration and version constraints
- `versions.tf`: Terraform and provider version requirements
- `backend.tf.example`: Remote backend configuration templates
- `.terraform.lock.hcl`: Provider lockfiles for deterministic builds

The configuration system prioritizes immutability, reproducibility, and separation of concerns across the bootstrap phases and stack deployments.