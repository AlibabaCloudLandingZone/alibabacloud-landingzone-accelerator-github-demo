---
kind: design
name: Single OSS state bucket with prefix-based isolation instead of per-spoke buckets
source: session
category: adr
---

# Single OSS state bucket with prefix-based isolation instead of per-spoke buckets

_Source: coding plans from commit period bd15e95 → e386753 — records intent at planning time; the implementation may lag or differ._

**Status:** accepted

## Context
Terraform state for multiple stacks (identity, log-archive, guardrails, network, security) must be persisted remotely with locking. The demo covers ~5 spoke accounts, so the choice is between one shared bucket or one bucket per spoke.

## Decision drivers
- operational simplicity at demo scale
- centralized lifecycle/encryption policy
- Tablestore lock table co-location

## Considered options
- **Single OSS bucket with stack-prefix separation** — pros: One encryption/lifecycle policy; single Tablestore lock table; simpler IAM; easier backup/restore; sufficient for ≤50 stacks; cons: Less strict isolation if someone gains bucket-level access
- **Separate OSS bucket per spoke account** _(rejected)_ — pros: Stronger isolation boundary per account; cons: N buckets to manage; N sets of lifecycle/encryption policies; N lock tables or cross-account lock coordination; overkill for 5 spokes

## Decision
Create one versioned, KMS-encrypted OSS bucket in the CICD account with a 90-day noncurrent expiry lifecycle rule, and one Tablestore instance/table for lock coordination. Each stack's backend block uses a unique `prefix` matching its directory path (e.g., `stacks/20-network-cen`).

## Consequences
State files are isolated by prefix and locked atomically via Tablestore. Lifecycle rules automatically clean old versions. At 50+ stacks the single-bucket model remains manageable; beyond that, per-account buckets could be reconsidered.