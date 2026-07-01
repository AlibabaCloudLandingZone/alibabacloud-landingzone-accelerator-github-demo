This repository does not implement an application-level logging system (no in-process loggers, structured log fields, or log sinks). Instead, it provisions Alibaba Cloud's platform-level logging and audit infrastructure via Terraform modules. The logging concern is entirely declarative IaC that configures cloud-native services for collecting, centralizing, alerting, and retaining operational logs across the landing zone accounts.

### What is provisioned
- **ActionTrail trails** (`modules/lza/components/log-archive/actiontrail/main.tf`) — organization-wide API call auditing with optional delivery to OSS buckets and SLS projects; supports multi-account aggregation via `is_organization_trail`.
- **Cloud Config recorder + aggregator** (`modules/lza/components/log-archive/config/main.tf`) — configuration-item change snapshots and notifications delivered to OSS/SLS through aggregate delivery channels.
- **SLS collection policies** (`modules/lza/components/log-archive/log-audit/main.tf`) — centralized collection of product-specific logs (e.g., ECS, RDS, CEN) into a dedicated SLS project/logstore with per-policy TTL and resource-directory scoping.
- **SLS event alerts** (`modules/lza/components/log-archive/event-alert/main.tf`) — user/group resource records plus policy scripts that fire on ActionTrail events using built-in templates.
- **Bootstrap spoke roles** (`bootstrap/02-spoke-bootstrap/main.tf`) — creates RAM roles scoped to the `log-archive` account so spoke stacks can deploy the above components cross-account.
- **Stack orchestration** (`.github/workflows/stacks.yml`) — matrix entry `{ name: "11-log-archive", account_key: "log-archive" }` triggers deployment of stack `stacks/11-log-archive/main.tf`, which currently contains only a TODO placeholder.

### Architecture and conventions
- **Provider aliasing**: each component uses a dedicated `alicloud.<alias>` provider (`log_archive`, `sls`, `oss`, `log_audit`, `sls_project`, `sls_resource_record`) pointing at the correct region/account, enabling cross-account provisioning from a single run.
- **Service enablement gate**: every module begins with `data "alicloud_log_service" "open" { enable = "On" }` / `data "alicloud_oss_service" "open" { enable = "On" }` before creating resources, ensuring the target service is active first.
- **Optional delivery toggles**: OSS and SLS delivery are controlled by boolean variables (`enable_oss_delivery`, `enable_sls_delivery`) with `count = var.enable_* ? 1 : 0` so consumers can pick one sink or both.
- **Naming defaults**: bucket/project names derive from the current account ID (`actiontrail-${account_id}`, `config-${account_id}`) when not explicitly supplied, guaranteeing uniqueness across accounts.
- **Shared sub-modules**: reusable `modules/sls-project`, `modules/sls-logstore`, `modules/oss-bucket` encapsulate naming suffixes, KMS encryption, retention, and shard tuning used uniformly across all logging components.
- **Guardrails separation**: the config aggregator comment notes duplication avoidance with `components/guardrails/detective`; the same aggregator should be reused rather than recreated.

### Rules developers should follow
- Always use the aliased providers (`alicloud.log_archive`, `alicloud.sls`, etc.) inside log-archive components instead of the default provider.
- Gate service-dependent resources behind the `alicloud_log_service.open` / `alicloud_oss_service.open` data sources.
- Prefer the shared `modules/sls-project` and `modules/oss-bucket` helpers for consistent naming, tagging, and encryption.
- When adding new collection policies, create the destination logstore via `alicloud_log_store.this` keyed by `policy_name` and reference it in `centralize_config.dest_logstore`.
- Reuse the existing Cloud Config aggregator (`var.use_existing_aggregator`) rather than spinning up a second one.
- Keep the `stacks/11-log-archive/main.tf` as a thin wrapper that calls the LZA component module once it is fully implemented.