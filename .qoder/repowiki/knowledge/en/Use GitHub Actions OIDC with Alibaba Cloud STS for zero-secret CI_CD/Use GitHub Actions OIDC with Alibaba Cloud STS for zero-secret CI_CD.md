---
kind: design
name: Use GitHub Actions OIDC with Alibaba Cloud STS for zero-secret CI/CD
source: session
category: adr
---

# Use GitHub Actions OIDC with Alibaba Cloud STS for zero-secret CI/CD

_Source: coding plans from commit period bd15e95 → e386753 — records intent at planning time; the implementation may lag or differ._

**Status:** accepted

## Context
The project must provision and manage multi-account Alibaba Cloud infrastructure from GitHub Actions without storing long-lived credentials. A traditional access-key approach would require managing secrets across many accounts and workflows.

## Decision drivers
- zero secret management overhead
- per-run short-lived tokens
- least-privilege via role chaining

## Considered options
- **GitHub Actions OIDC → Hub Role → Spoke Role chain** — pros: No stored secrets; tokens scoped to repo/pull_request/environment; automatic rotation via OIDC; aligns with LZA reference design; cons: Requires initial bootstrap of OIDC provider and roles in the CICD account
- **Static ALICLOUD_ACCESS_KEY / ALICLOUD_SECRET_KEY per workflow** _(rejected)_ — pros: Simpler initial setup; cons: Secret sprawl across repos; no automatic rotation; harder to scope permissions; violates least-privilege at scale

## Decision
Bootstrap an `alicloud_ims_oidc_provider` pointing at `https://token.actions.githubusercontent.com`, create hub roles (`GitHubActionsPlanRole`, `GitHubActionsApplyRole`) trusted by the OIDC provider, and spoke roles (`SpokePlanRole`, `SpokeApplyRole`) that trust the hub roles. Workflows assume the hub role via `aliyun/configure-aliyun-credentials-action` with `role-to-assume` and `oidc-provider-arn`, then optionally chain into a spoke role for target-account provisioning.

## Consequences
Eliminates all long-lived credential storage in GitHub Secrets. Plan vs. apply separation is enforced via distinct OIDC sub claims (`pull_request` vs. `environment:production`). Adding a new spoke account only requires creating its spoke roles — no workflow or secret changes. The 1-hour session duration limits blast radius but may require longer sessions for very large applies.