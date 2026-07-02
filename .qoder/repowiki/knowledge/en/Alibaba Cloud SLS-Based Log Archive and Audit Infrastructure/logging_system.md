This repository does not implement an application-level logging framework (no Go/Python logger, no structured log levels, no in-process log sinks). Instead, it provisions Alibaba Cloud's centralized logging and audit infrastructure — primarily **SLS (Simple Log Service)**, **ActionTrail**, and **Cloud Config** — as Terraform modules that collect, aggregate, and deliver cloud control-plane and product logs into dedicated SLS projects and OSS buckets. The system is purely IaC-driven; runtime log generation is delegated to the platform services themselves.

### What system/approach is used
- **SLS (Simple Log Service)**: primary sink for collected logs via `alicloud_log_store`, `alicloud_sls_collection_policy`, and reusable `modules/sls-project` / `modules/sls-logstore`.
- **ActionTrail**: records API-call audit events, delivered to either OSS or SLS through `alicloud_actiontrail_trail` with optional organization-wide scope.
- **Cloud Config**: configuration compliance snapshots and change notifications aggregated via `alicloud_config_aggregator` and delivered to OSS/SLS.
- **SLS Alerting**: user/resource records and action policies (`sls.alert.action_policy`) drive SMS/voice/email alert routing against ActionTrail event streams.
- All resources are created through the **Alibaba Cloud Terraform Provider** (`alicloud`), using provider aliases (`alicloud.log_archive`, `alicloud.sls_project`, `alicloud.log_audit`, `alicloud.sls_resource_record`) to target different accounts/regions.

### Key files and packages
- `modules/lza/components/log-archive/actiontrail/main.tf` — ActionTrail trail with OSS/SLS delivery, service enablement, and RAM role wiring.
- `modules/lza/components/log-archive/config/main.tf` — Cloud Config recorder + aggregator + OSS/SLS aggregate delivery channels.
- `modules/lza/components/log-archive/event-alert/main.tf` — SLS resource records (users, groups) and action policy script generator for alert routing.
- `modules/lza/components/log-archive/log-audit/main.tf` — Centralized SLS collection policies per product/data_code with per-policy logstore creation and cross-account scoping.
- `modules/lza/modules/sls-project/` and `modules/lza/modules/sls-logstore/` — Reusable SLS project/logstore builders shared across components.
- `bootstrap/02-spoke-bootstrap/providers.tf` & `variables.tf` — Cross-account provider alias `log_archive` pointing at the log-archive spoke account.
- `stacks/11-log-archive/main.tf` — Placeholder stack entrypoint (marked TODO).

### Architecture and conventions
- **Per-component isolation**: each subdirectory under `components/log-archive/*` owns one concern (actiontrail, config, event-alert, log-audit) and exposes a self-contained module with explicit `enable_*` toggles.
- **Dual-delivery pattern**: every component supports both OSS and SLS destinations behind boolean flags (`enable_oss_delivery`, `enable_sls_delivery`), defaulting to disabled so consumers opt in.
- **Resource naming**: names are derived from account IDs (`actiontrail-${account_id}`, `config-${account_id}`) with optional random suffixes (`append_random_suffix`, `random_suffix_length`, `random_suffix_separator`) to guarantee global uniqueness across accounts.
- **Provider aliasing**: all log-archive resources use `provider = alicloud.log_archive` (or `alicloud.sls_project`, `alicloud.log_audit`, `alicloud.sls_resource_record`) rather than the default provider, enabling multi-account deployment without long-lived credentials.
- **Aggregator reuse**: the config component supports `use_existing_aggregator` / `existing_aggregator_id` to avoid duplicate aggregators when guardrails/detective also creates one.
- **Validation-first variables**: every variable includes Terraform `validation {}` blocks enforcing naming regexes, enum sets, and cross-field constraints (e.g., `hot_ttl <= retention_period`, required `data_region` for specific product/data_code combos).
- **Collection policy model**: `log-audit` accepts a typed `collection_policies` list where each entry declares `product_code` + `data_code`, `policy_config.resource_mode` (all/attributeMode/instanceMode), optional `resource_directory` scoping, and a nested `logstore` block controlling name/create/shards/TTL/mode/metering.

### Rules developers should follow
1. **Use the provided modules** — do not inline `alicloud_log_store` / `alicloud_sls_collection_policy` directly; compose via `modules/lza/components/log-archive/*` to inherit validation and defaults.
2. **Enable only what you need** — set `enable_oss_delivery` / `enable_sls_delivery` explicitly; defaults are `false` to prevent accidental cost.
3. **Prefer SLS over OSS for active querying** — OSS is suitable for cold archival; SLS logstores support real-time query and alerting.
4. **Reuse existing aggregators/projects** — when multiple stacks share a destination, pass `use_existing_aggregator` / `create_project = false` plus the concrete ID/name instead of creating duplicates.
5. **Follow naming validations** — project/logstore names must match the enforced regexes; rely on the built-in `coalesce(var.name, "prefix-${account_id}")` defaults unless you have a strong reason to override.
6. **Configure alerts through the event-alert module** — define users/user_groups once and reference them via `action_policy_scripts`; avoid hand-editing SLS alert rules outside Terraform.
7. **Scope collection policies correctly** — pick `resource_mode` according to the product/data_code matrix validated in the module; `attributeMode` requires `regions`, `instanceMode` requires `instance_ids`.