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

### Phase 1 — Organization Structure + Spoke Roles

> **Note:** ROS must be a trusted service in the Resource Directory before a SERVICE_MANAGED stack group can deploy into member accounts. This stack enables it itself, via an ROS stack using `ALIYUN::ROS::AutoEnableService` with `ServiceName = TrustedService/ROS` — no console step required.

```bash
cd bootstrap/00-org-structure
terraform init
terraform apply
```

Creates: Resource Directory, folders, member accounts, and `SpokeDeployRole` in every **member** account — via a SERVICE_MANAGED ROS stack group using `templates/spoke-roles.json`.

> **Note:** the spoke role trust policy references the hub roles created in Phase 2; Alibaba RAM accepts the principal ARN before the roles exist, so the order 00 → 01 still works.

#### Seeding the management role

The management account's `SpokeDeployRole` cannot come from ROS: CI must already be able to assume it in order to run this stage. Create it once with management-account credentials, substituting your CICD (hub) account ID:

```bash
HUB=1234567890123456
aliyun ram CreateRole --RoleName SpokeDeployRole --MaxSessionDuration 3600 \
  --Description "Role assumed by the hub GitHubActions roles for terraform plan and apply." \
  --AssumeRolePolicyDocument "{\"Version\":\"1\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"sts:AssumeRole\",\"Principal\":{\"RAM\":[\"acs:ram::$HUB:role/GitHubActionsPlanRole\",\"acs:ram::$HUB:role/GitHubActionsApplyRole\"]}}]}"
aliyun ram AttachPolicyToRole --PolicyType System --PolicyName AdministratorAccess --RoleName SpokeDeployRole
```

Then hand it to Terraform so the trust policy lives in code from that point on:

```bash
terraform import alicloud_ram_role.spoke_deploy_management SpokeDeployRole
terraform import alicloud_ram_role_policy_attachment.spoke_deploy_management role:AdministratorAccess:System:SpokeDeployRole
```

> **Note:** RAM stores principal ARNs lowercased, which is why the trust policy in `main.tf` wraps them in `lower()`. Without that, every plan reports a spurious in-place update.

The hub policies already allow `sts:AssumeRole` on `acs:ram::*:role/SpokeDeployRole`, so no policy change is needed. After this, CI runs Phase 1 itself: the workflow passes `management_role_arn`, and the provider chains hub role → management `SpokeDeployRole`. Local runs leave `management_role_arn` empty and use ambient management-account credentials.

### Phase 2 — CI/CD Foundation

```bash
cd bootstrap/01-cicd-foundation
terraform init
terraform apply
```

Creates: OIDC provider, hub Plan/Apply roles, OSS state bucket, Tablestore lock table.

> **Migrating from the old 02-spoke-bootstrap stage:** ROS cannot adopt the existing `SpokePlanRole`/`SpokeApplyRole`. Run `terraform destroy` in the old `bootstrap/02-spoke-bootstrap` first, then apply `00-org-structure`. Stack CI cannot assume spoke roles during that window.

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
| `SPOKE_ACCOUNT_IDS_JSON` | JSON map of spoke accounts. Must include `management` and `iam` for the Cloud SSO stack | `{"management":"111...","iam":"222...","devops":"123...","log-archive":"456...","security":"789..."}` |
| `TFSTATE_BUCKET` | OSS bucket holding Terraform state | `lza-tfstate-1234567890123456` |
| `TFSTATE_REGION` | Region of the state bucket and lock table | `cn-hangzhou` |
| `TFSTATE_TABLESTORE_ENDPOINT` | Tablestore endpoint used for state locking | `https://tflock-123456.cn-hangzhou.ots.aliyuncs.com` |
| `TFSTATE_TABLESTORE_TABLE` | Tablestore lock table name | `tflock` |

The workflows build the OSS backend configuration from these four variables at `terraform init` time. `backend.tfbackend` is for local use only and is intentionally not committed, so the bucket name and account ID stay out of this public repository.

## Security Model

- **No long-lived credentials** — GitHub OIDC tokens are exchanged for short-lived STS tokens at every workflow run.
- **OIDC-gated hub roles** — The Plan role is only assumable from pull requests; the Apply role is restricted to the `production` GitHub environment with required reviewers and is the only role with state-write access.
- **Single spoke role** — Each account has one `SpokeDeployRole` (trusted by both hub roles). Plan and apply share it because alicloud provider data sources activate services, which requires permissions beyond `ReadOnlyAccess`.
- **Account isolation** — Each spoke account has its own IAM role; a compromise of one role cannot affect other accounts.
- **Encrypted state** — Terraform state is stored in OSS with server-side KMS encryption.
- **State locking** — Tablestore provides distributed locking to prevent concurrent applies.

## Cloud SSO

`stacks/10-identity-cloudsso` provisions the centralised workforce identity layer: directory, password/MFA policy, SAML federation, SCIM provisioning, access configurations (permission sets), groups, users, and account assignments.

It differs from the other stacks in three ways:

- **Two accounts.** The directory is created in the Resource Directory management account; access configurations, principals and assignments are managed from the `iam` member account, which `bootstrap/00-org-structure` registers as the Cloud SSO delegated administrator. The pipeline therefore injects both `TF_VAR_spoke_role_arn` (management) and `TF_VAR_iam_role_arn` (iam).
- **Region.** Cloud SSO has no `cn-hangzhou` endpoint, so this stack defaults to `cn-shanghai`.
- **Raw resources.** The vendored LZA component (`modules/lza/components/identity/cloudsso`) does not expose SAML or SCIM settings, which are inline attributes of the directory resource it owns, so the resources are declared directly in the stack.

### Connecting an external identity provider

1. Apply the stack once and read the `saml_service_provider` output — it carries the ACS URL, SP entity ID and SP metadata document needed by the IdP.
2. Register the SP in the IdP, then set `saml_identity_provider` (`entity_id`, `login_url`, `encoded_metadata_document`) and re-apply. It defaults to `null` because the API rejects placeholder metadata.
3. SCIM sync is enabled on the directory by default. The SCIM server credential secret is only returned at creation time and cannot be recovered, so generate it in the console rather than in CI (`create_scim_server_credential` stays `false`).

## Day-2 Operations

### Adding a New Spoke Account

1. Add the new account to `account_mapping` in `bootstrap/00-org-structure` (prod.tfvars).
2. Run `terraform apply` in `bootstrap/00-org-structure` — the account and its `SpokeDeployRole` (ROS stack instance) are created together.
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
│   ├── 00-org-structure/         # Phase 1: RD, folders, member accounts, spoke roles (ROS)
│   │   └── templates/            # Shared ROS template for SpokeDeployRole
│   └── 01-cicd-foundation/       # Phase 2: OSS state, OIDC, hub roles
├── stacks/
│   ├── 10-identity-cloudsso/     # Directory, SAML/SCIM, permission sets, assignments
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
