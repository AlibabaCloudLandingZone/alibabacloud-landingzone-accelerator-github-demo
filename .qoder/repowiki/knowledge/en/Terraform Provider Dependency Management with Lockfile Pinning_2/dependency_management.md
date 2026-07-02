This repository manages dependencies exclusively through Terraform's provider dependency system. There are no Go, Node.js, or other language package managers present — the entire codebase is Infrastructure-as-Code using Terraform against Alibaba Cloud (Alicloud) via the `aliyun/alicloud` provider.

**System and approach**
- Each Terraform root module (under `bootstrap/`, `stacks/`, and individual components under `modules/lza/components/`) declares its own provider requirements in a `versions.tf` file using `required_providers { alicloud = { source = "aliyun/alicloud", version = ">= X.Y.Z" } }`.
- A per-module `.terraform.lock.hcl` lockfile is committed alongside each root module, pinning the exact resolved provider binary (`version = "1.280.0"`) along with its constraint (`constraints = ">= 1.262.1"`) and cryptographic hash (`hashes = [h1:...]`). This ensures deterministic provider downloads across CI and local runs.
- The `modules/lza/` library uses slightly looser constraints (e.g., `~> 1.267`) to allow patch-level flexibility within major versions for reusable components consumed by multiple stacks.
- No vendoring of providers into the repository; providers are downloaded on-demand from the Terraform Registry at `registry.terraform.io/aliyun/alicloud` during `terraform init`. The `.gitignore` does not exclude `.terraform/` directories that contain cached provider binaries, but the lockfiles themselves are tracked.
- There is no private registry configuration, no `GOPRIVATE`, no `go.mod`, and no `package.json` — this is purely a Terraform-only project.

**Key files**
- `bootstrap/00-org-structure/.terraform.lock.hcl` — pinned `aliyun/alicloud@1.280.0` with constraint `>= 1.262.1`
- `bootstrap/01-cicd-foundation/.terraform.lock.hcl` — identical pin/constraint
- `bootstrap/02-spoke-bootstrap/.terraform.lock.hcl` — identical pin/constraint
- `stacks/10-identity-cloudsso/.terraform.lock.hcl` — identical pin/constraint
- `bootstrap/00-org-structure/versions.tf` — declares `required_version = ">= 1.5"` and `alicloud >= 1.262.1`
- `modules/lza/components/guardrails/detective/versions.tf` — demonstrates the looser `~> 1.267` pattern used in shared modules
- `stacks/12-guardrails-preventive/providers.tf` — shows cross-account provider configuration via `assume_role`, relevant because it affects which environment credentials resolve provider access

**Architecture and conventions**
- Per-root-module isolation: every bootstrap phase and stack directory is an independent Terraform root with its own lockfile, so provider updates can be rolled out incrementally rather than globally.
- Constraint strategy: production-facing roots use a lower-bound constraint (`>= 1.262.1`) while the reusable component library uses a tilde constraint (`~> 1.267`) to permit safe patch upgrades without breaking downstream consumers.
- Determinism via hashes: the lockfile includes the SHA-256 hash of the provider plugin archive, preventing supply-chain drift even if the same version number were re-published.
- No backend coupling in dependency declarations: Phase 1 starts with the default local backend (explicitly noted in comments) and migrates to OSS-backed state in Phase 2, keeping provider management decoupled from state storage.

**Rules developers should follow**
- Always declare provider requirements in `versions.tf` using `required_providers` with an explicit minimum version constraint; never rely on implicit latest resolution.
- Commit the generated `.terraform.lock.hcl` alongside your root module so CI and teammates get the exact same provider binary.
- When updating providers, run `terraform init -upgrade` in the affected root module, review the diff in `.terraform.lock.hcl`, and ensure the new version still satisfies all downstream consumers before merging.
- For reusable modules under `modules/lza/`, prefer tilde constraints (`~> X.Y`) to allow patch-level flexibility; for production roots, prefer open lower bounds (`>= X.Y.Z`) paired with a locked upper bound in the lockfile.
- Do not vendor provider plugins into the repository; let `terraform init` download them from the registry as recorded by the lockfile.