---
kind: design
name: Align provider source to `hashicorp/alicloud` to match LZA modules
source: session
category: adr
---

# Align provider source to `hashicorp/alicloud` to match LZA modules

_Source: coding plans from commit period f54f741 → da7fa29 — records intent at planning time; the implementation may lag or differ._

**Status:** accepted

## Context
The LZA modules declare `hashicorp/alicloud ~> 1.267` while the bootstrap's `bootstrap/00-org-structure/versions.tf` used `aliyun/alicloud >= 1.262.1`. Terraform rejects mixing different registry namespaces for the same provider name, blocking the refactor to LZA modules.

## Decision drivers
- compatibility with LZA module provider constraints
- use the standard HashiCorp registry path
- avoid maintaining a fork of LZA just to change the provider source

## Considered options
- **Switch root module to `hashicorp/alicloud`** — pros: matches LZA modules out of the box; standard registry path; no fork needed; cons: breaks existing `.terraform.lock.hcl` until re-init
- **Fork/modify LZA modules to use `aliyun/alicloud`** _(rejected)_ — pros: keeps current provider source unchanged; cons: ongoing maintenance burden keeping the fork in sync with upstream LZA

## Decision
Update `bootstrap/00-org-structure/versions.tf` to require `hashicorp/alicloud >= 1.267.0`, matching the LZA modules' declared source and version range.

## Consequences
Existing lock files must be regenerated (`rm .terraform.lock.hcl && terraform init`). Both sources deliver the same provider binary, so runtime behavior is unchanged, but any other module still using `aliyun/alicloud` will need the same migration.