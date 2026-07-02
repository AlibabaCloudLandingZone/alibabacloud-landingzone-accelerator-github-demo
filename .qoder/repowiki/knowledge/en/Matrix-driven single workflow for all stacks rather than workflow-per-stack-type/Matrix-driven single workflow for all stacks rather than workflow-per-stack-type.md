---
kind: design
name: Matrix-driven single workflow for all stacks rather than workflow-per-stack-type
source: session
category: adr
---

# Matrix-driven single workflow for all stacks rather than workflow-per-stack-type

_Source: coding plans from commit period bd15e95 → e386753 — records intent at planning time; the implementation may lag or differ._

**Status:** accepted

## Context
The repository contains 8 skeleton stacks plus 3 bootstrap phases. The question is whether to write one reusable workflow invoked per stack type or a single workflow that dynamically discovers and runs all stacks.

## Decision drivers
- demonstration clarity
- low maintenance overhead for 5 accounts
- avoid over-engineering

## Considered options
- **Single `stacks.yml` with matrix strategy over dynamic account list** — pros: One workflow file; plan jobs run in parallel with unlimited concurrency; apply gated behind `environment: production`; derived spoke role ARNs at runtime from `SPOKE_ACCOUNT_IDS_JSON` variable; cons: All stacks share the same workflow logic; less explicit per-stack control
- **Workflow-per-stack-type (one per identity/log/guardrails/network/security)** _(rejected)_ — pros: Explicit triggers and permissions per domain; cons: Duplication of workflow logic; hard to coordinate cross-stack ordering; unnecessary complexity for a demo with 5 core accounts

## Decision
Use one `.github/workflows/stacks.yml` with a matrix over stack names, deriving the spoke role ARN at runtime from the `SPOKE_ACCOUNT_IDS_JSON` repository variable. Plan jobs have no concurrency limit; apply jobs serialize to `max-parallel: 1` and require the `production` environment.

## Consequences
Adding a new stack means adding a directory under `stacks/` and updating `SPOKE_ACCOUNT_IDS_JSON`. Cross-stack dependency ordering is not enforced by the workflow — it relies on manual PR sequencing. This is acceptable for the demo but would need a DAG orchestrator at larger scale.