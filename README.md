# Alibaba Cloud Landing Zone Accelerator — GitHub Actions Demo

Demonstrate how to deploy and manage an Alibaba Cloud Landing Zone using **Terraform** and **GitHub Actions** with OIDC federation — no long-lived credentials required.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  GitHub Actions                                                      │
│                                                                      │
│  1. Request OIDC Token                                               │
│        │                                                             │
│        ▼                                                             │
│  2. AssumeRole → Hub Role (CICD Account)                             │
│        │                                                             │
│        ▼                                                             │
│  3. AssumeRole → Spoke Role (Member Account)                         │
│        │                                                             │
│        ▼                                                             │
│  4. Provision Resources in Target Account                            │
└──────────────────────────────────────────────────────────────────────┘

State Backend:
  • OSS bucket (encrypted with KMS) — stores Terraform state
  • Tablestore instance — provides state locking
```

**Credential flow:** GitHub OIDC Token → Hub Role (CICD account) → Spoke Role (member account) → Resources

## Prerequisites

| Requirement | Notes |
|---|---|
| Alibaba Cloud account with **Resource Directory** enabled | Management account or delegated admin |
| GitHub repository | Public or private |
| Terraform >= 1.5 | Required for OIDC-based auth with the alicloud provider |
| Alibaba Cloud CLI | Used for bootstrap state migration (`aliyun oss`) |
| Short-lived operator AccessKey | For bootstrap phases only; revoke after pipeline is live |

## Quick Start

### Phase 0 — Manual Account Hygiene

1. Enable MFA on the management account root user.
2. Complete real-name verification for all member accounts.
3. Enable Resource Directory in the management account console.

### Phase 1 — Organization Structure

```bash
cd bootstrap/00-org-structure
terraform init
terraform apply
```

Creates: Resource Directory, folders, member accounts.

### Phase 2 — CI/CD Foundation

```bash
cd bootstrap/01-cicd-foundation
terraform init
terraform apply
```

Creates: OIDC provider, hub Plan/Apply roles, OSS state bucket, Tablestore lock table.

### Phase 3 — Spoke Bootstrap

```bash
cd bootstrap/02-spoke-bootstrap
terraform init
terraform apply
```

Creates: Spoke roles in each member account that trust the hub roles.

### State Migration

After Phase 2 provisions the OSS backend, migrate each bootstrap stack's local state:

```bash
# Add the backend block (see backend.tf.example), then:
terraform init -migrate-state
```

Repeat for each bootstrap directory.

### Phase 4+ — Pipeline Takes Over

1. Push the repository to GitHub.
2. Configure the required repository variables (see below).
3. Open a PR — the pipeline runs `terraform plan`.
4. Merge to `main` — the pipeline runs `terraform apply`.

## GitHub Repository Variables

| Variable | Description | Example |
|---|---|---|
| `HUB_ACCOUNT_ID` | CICD hub account ID | `1234567890123456` |
| `GHA_PLAN_ROLE_ARN` | Plan role ARN | `acs:ram::1234567890123456:role/GitHubActionsPlanRole` |
| `GHA_APPLY_ROLE_ARN` | Apply role ARN | `acs:ram::1234567890123456:role/GitHubActionsApplyRole` |
| `OIDC_PROVIDER_ARN` | OIDC provider ARN | `acs:ram::1234567890123456:oidc-provider/GitHubActions` |
| `SPOKE_ACCOUNT_IDS_JSON` | JSON map of spoke accounts | `{"devops":"123...","log-archive":"456...","security":"789..."}` |

## Security Model

- **No long-lived credentials** — GitHub OIDC tokens are exchanged for short-lived STS tokens at every workflow run.
- **Least-privilege roles** — The Plan role (read-only) is used on pull requests; the Apply role (read-write) is restricted to the `production` GitHub environment with required reviewers.
- **Account isolation** — Each spoke account has its own IAM role; a compromise of one role cannot affect other accounts.
- **Encrypted state** — Terraform state is stored in OSS with server-side KMS encryption.
- **State locking** — Tablestore provides distributed locking to prevent concurrent applies.

## Day-2 Operations

### Adding a New Spoke Account

1. Add the new account to the `spokes` variable in `bootstrap/02-spoke-bootstrap/variables.tf`.
2. Run `terraform apply` in `bootstrap/02-spoke-bootstrap`.
3. Update `SPOKE_ACCOUNT_IDS_JSON` in the GitHub repository variables.

### Adding a New Stack

1. Copy an existing stack (e.g., `stacks/20-network-cen`) as a template.
2. Update `providers.tf` and `variables.tf` to target the desired account.
3. Add the new stack to the `matrix` in `.github/workflows/stacks.yml`.
4. Open a PR to validate the plan.

### Drift Detection

Schedule plan-only workflow runs (e.g., nightly) to detect configuration drift:

```yaml
on:
  schedule:
    - cron: '0 2 * * *'
```

The reusable workflow (`terraform-reusable.yml`) already supports plan-only mode.

## Project Structure

```
├── bootstrap/
│   ├── 00-org-structure/         # Phase 1: RD, folders, member accounts
│   ├── 01-cicd-foundation/       # Phase 2: OSS state, OIDC, hub roles
│   └── 02-spoke-bootstrap/       # Phase 3: spoke roles in member accounts
│       └── modules/spoke-roles/  # Reusable spoke role module
├── stacks/
│   ├── 10-identity-cloudsso/
│   ├── 11-log-archive/
│   ├── 12-guardrails-preventive/
│   ├── 13-guardrails-detective/
│   ├── 20-network-cen/           # Fully implemented example
│   ├── 21-network-dmz/
│   ├── 30-security-kms/
│   ├── 30-security-firewall/
│   └── 30-security-waf/
└── .github/workflows/
    ├── terraform-reusable.yml    # Core reusable workflow
    ├── bootstrap-00-org-structure.yml
    ├── bootstrap-01-cicd-foundation.yml
    ├── bootstrap-02-spoke.yml
    └── stacks.yml                # Matrix-driven stack deployment
```

## References

- [Alibaba Cloud RAM — OIDC Provider Documentation](https://www.alibabacloud.com/help/en/ram/user-guide/overview-of-oidc-based-sso)
- [aliyun/configure-aliyun-credentials-action](https://github.com/aliyun/configure-aliyun-credentials-action) — GitHub Action for OIDC-based credential configuration
- [Terraform Alibaba Cloud Provider](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs)
- [Terraform OSS Backend](https://www.alibabacloud.com/help/en/oss/developer-reference/terraform-backend-type)
- [Landing Zone Accelerator on Alibaba Cloud](https://github.com/aliyun/alibabacloud-landing-zone)

## License

See [LICENSE](./LICENSE).
# alibabacloud-landingzone-accelerator-github-demo
Demo for how to run Alibaba Cloud landing zone accelerator in GitHub Actions
