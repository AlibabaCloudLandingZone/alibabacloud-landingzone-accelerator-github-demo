This repository has no traditional build system (no Makefile, Dockerfile, or shell build scripts). The entire "build" is an Infrastructure-as-Code pipeline driven by GitHub Actions workflows that orchestrate Terraform against Alibaba Cloud via OIDC-federated short-lived credentials.

### System overview
- **Orchestrator**: GitHub Actions (`.github/workflows/`).
- **IaC engine**: HashiCorp Terraform (`hashicorp/setup-terraform@v3`, pinned to `1.9.5` in every workflow).
- **Cloud provider**: Alibaba Cloud via the `aliyun/alicloud` Terraform provider; authentication uses `aliyun/configure-aliyun-credentials-action@v1` with OIDC (`id-token: write` permission) — no long-lived AK/SK.
- **State backend**: Remote state stored in Alibaba Cloud OSS per stack directory (each `bootstrap/*` and `stacks/*` folder contains its own `.terraform.lock.hcl` and `providers/registry.terraform.io/...` cache).

### Workflow architecture
A single reusable workflow centralizes all Terraform steps:

- **`.github/workflows/terraform-reusable.yml`** — called via `workflow_call`; accepts `working_directory`, `role_to_assume`, `oidc_provider_arn`, optional `spoke_role_arn`, and `terraform_action` (`plan` | `apply`). It runs `terraform init`, then either `plan` (with PR comment attachment) or `apply -auto-approve`.

Four thin wrapper workflows invoke it for the three bootstrap phases:
- `bootstrap-00-org-structure.yml` → `bootstrap/00-org-structure`
- `bootstrap-01-cicd-foundation.yml` → `bootstrap/01-cicd-foundation`
- `bootstrap-02-spoke.yml` → `bootstrap/02-spoke-bootstrap`

One matrix-driven workflow deploys production stacks:
- `stacks.yml` — plans/applies each subdirectory under `stacks/` (`10-identity-cloudsso`, `11-log-archive`, `12-guardrails-preventive`, `13-guardrails-detective`, `20-network-cen`, `21-network-dmz`, `30-security-kms`, `30-security-firewall`, `30-security-waf`) in parallel during plan, serially (`max-parallel: 1`) during apply.

### Trigger & gating model
- Pull requests trigger `plan` only, with path filters scoped to changed directories; the plan diff is posted as a PR comment.
- Pushes to `refs/heads/main` trigger `apply`, gated by `environment: production` on the reusable workflow and on `stacks.yml`.

### Credential & role chaining flow
- Plan jobs assume `GHA_PLAN_ROLE_ARN` (hub account).
- Apply jobs assume `GHA_APPLY_ROLE_ARN` (hub account), which then chains into a spoke role passed via `TF_VAR_spoke_role_arn` (e.g. `SpokePlanRole` / `SpokeApplyRole`).
- All secrets are repo-level GitHub Actions variables (`OIDC_PROVIDER_ARN`, `GHA_PLAN_ROLE_ARN`, `GHA_APPLY_ROLE_ARN`, `SPOKE_ACCOUNT_IDS_JSON`).

### Conventions developers should follow
1. Add a new stack by creating a `stacks/<NN>-<name>/` directory with the standard Terraform files and adding an entry to the matrix in `stacks.yml`.
2. Bootstrap changes go under `bootstrap/<phase>-<name>/`; add a corresponding workflow file following the pattern of the existing `bootstrap-XX-*.yml` wrappers.
3. Never hardcode credentials — rely on OIDC variables from the repo settings.
4. Pin Terraform versions consistently at `1.9.5` across all workflows to avoid drift.
5. Use path filters in `on.pull_request.paths` so unrelated PRs do not trigger unnecessary plans.