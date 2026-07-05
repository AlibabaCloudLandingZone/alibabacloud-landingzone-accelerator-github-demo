---
kind: design
name: Use Git submodule to consume LZA components
source: session
category: adr
---

# Use Git submodule to consume LZA components

_Source: coding plans from commit period f54f741 → da7fa29 — records intent at planning time; the implementation may lag or differ._

**Status:** accepted

## Context
The project needs to consume the upstream `aliyun/landing-zone-accelerator-on-alibaba-cloud` (LZA) component modules referenced in Section 21.7 of the design document, but the upstream repo has no tags or releases and the bootstrap code currently contains inline resource definitions.

## Decision drivers
- ability to edit LZA sources locally without forking
- easy upstream sync via `git submodule update --remote`
- avoid GitHub API rate limits on every `terraform init`

## Considered options
- **Git submodule at `modules/lza/` pinned to `main`** — pros: local edits possible; simple upstream sync; matches design doc recommendation; cons: no semantic version pin — must track `main` branch
- **Vendor as checked-in copy** _(rejected)_ — pros: fully deterministic snapshot; cons: manual merge burden when upstream changes; harder to keep in sync
- **Reference GitHub source directly in Terraform** _(rejected)_ — pros: no local copy to maintain; cons: hits GitHub on every `terraform init`; no local edits possible without a fork

## Decision
Add the LZA repo as a git submodule at `modules/lza/` and pin it to the `main` branch (the only available ref), with all nine stack files referencing `../../modules/lza/components/<path>`.

## Consequences
Upstream changes are pulled via `git submodule update --remote`; there is no tag-based reproducibility so CI should record the resolved commit SHA. Local modifications to LZA components can be committed alongside the root module.