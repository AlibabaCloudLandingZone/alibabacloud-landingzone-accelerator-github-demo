# State Security

<cite>
**Referenced Files in This Document**
- [README.md](file://README.md)
- [backend.tf.example](file://bootstrap/01-cicd-foundation/backend.tf.example)
- [main.tf](file://bootstrap/01-cicd-foundation/main.tf)
- [outputs.tf](file://bootstrap/01-cicd-foundation/outputs.tf)
- [providers.tf](file://bootstrap/01-cicd-foundation/providers.tf)
- [variables.tf](file://bootstrap/01-cicd-foundation/variables.tf)
- [main.tf](file://bootstrap/02-spoke-bootstrap/main.tf)
- [variables.tf](file://bootstrap/02-spoke-bootstrap/variables.tf)
- [main.tf](file://bootstrap/02-spoke-bootstrap/modules/spoke-roles/main.tf)
- [variables.tf](file://bootstrap/02-spoke-bootstrap/modules/spoke-roles/variables.tf)
- [terraform-reusable.yml](file://.github/workflows/terraform-reusable.yml)
- [bootstrap-01-cicd-foundation.yml](file://.github/workflows/bootstrap-01-cicd-foundation.yml)
- [main.tf](file://stacks/30-security-kms/main.tf)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Dependency Analysis](#dependency-analysis)
7. [Performance Considerations](#performance-considerations)
8. [Troubleshooting Guide](#troubleshooting-guide)
9. [Conclusion](#conclusion)
10. [Appendices](#appendices)

## Introduction
This document explains the encrypted state management architecture using Alibaba Cloud OSS as the backend with Tablestore (OTS) for distributed locking. It covers the state infrastructure setup (versioning, server-side encryption with KMS, lifecycle policies), distributed locking mechanics, backend configuration, state migration procedures, and security controls. It also addresses integrity verification, drift detection, and secure state sharing patterns.

## Project Structure
The repository organizes state infrastructure provisioning in the CICD foundation phase and operational workflows in GitHub Actions. The key elements are:
- State infrastructure: OSS bucket with versioning and SSE-KMS, OTS instance/table for locking
- OIDC provider and hub roles for GitHub Actions
- Spoke roles in member accounts for least-privilege access
- Reusable workflow orchestrating plan/apply with OIDC-based credentials

```mermaid
graph TB
subgraph "CI/CD Foundation (CICD Account)"
B["OSS Bucket<br/>Versioning + SSE-KMS"]
L["OTS Instance/Table<br/>Distributed Locking"]
P["OIDC Provider<br/>GitHub Actions"]
RP["Plan Role (read-only)"]
RA["Apply Role (read-write)"]
end
subgraph "Member Accounts (Spoke Accounts)"
SRP["Spoke Plan Role"]
SRA["Spoke Apply Role"]
end
GH["GitHub Actions"] --> P
P --> RP
P --> RA
RP --> SRP
RA --> SRA
SRP --> B
SRA --> B
SRA --> L
```

**Diagram sources**
- [main.tf](file://bootstrap/01-cicd-foundation/main.tf)
- [outputs.tf](file://bootstrap/01-cicd-foundation/outputs.tf)
- [providers.tf](file://bootstrap/01-cicd-foundation/providers.tf)
- [main.tf](file://bootstrap/02-spoke-bootstrap/modules/spoke-roles/main.tf)
- [terraform-reusable.yml](file://.github/workflows/terraform-reusable.yml)

**Section sources**
- [README.md](file://README.md)
- [main.tf](file://bootstrap/01-cicd-foundation/main.tf)
- [outputs.tf](file://bootstrap/01-cicd-foundation/outputs.tf)
- [providers.tf](file://bootstrap/01-cicd-foundation/providers.tf)
- [variables.tf](file://bootstrap/01-cicd-foundation/variables.tf)
- [main.tf](file://bootstrap/02-spoke-bootstrap/main.tf)
- [variables.tf](file://bootstrap/02-spoke-bootstrap/variables.tf)
- [main.tf](file://bootstrap/02-spoke-bootstrap/modules/spoke-roles/main.tf)
- [variables.tf](file://bootstrap/02-spoke-bootstrap/modules/spoke-roles/variables.tf)
- [terraform-reusable.yml](file://.github/workflows/terraform-reusable.yml)
- [bootstrap-01-cicd-foundation.yml](file://.github/workflows/bootstrap-01-cicd-foundation.yml)

## Core Components
- Encrypted state storage on OSS:
  - Versioning enabled to preserve historical state
  - Server-side encryption with KMS
  - Lifecycle rule to expire noncurrent object versions after a retention period
- Distributed locking via OTS:
  - OTS instance configured as Capacity
  - Dedicated table with a string primary key and single-version TTL
- Backend configuration:
  - OSS backend block specifying bucket, prefix, key, region, OTS endpoint, and table
- Security model:
  - OIDC provider for GitHub Actions
  - Hub roles with scoped permissions for state access and assume-role on spokes
  - Spoke roles with least-privilege policies attached

**Section sources**
- [main.tf](file://bootstrap/01-cicd-foundation/main.tf)
- [backend.tf.example](file://bootstrap/01-cicd-foundation/backend.tf.example)
- [outputs.tf](file://bootstrap/01-cicd-foundation/outputs.tf)
- [variables.tf](file://bootstrap/01-cicd-foundation/variables.tf)

## Architecture Overview
The state backend architecture combines secure object storage with distributed locking to prevent concurrent modifications. The CI/CD workflow authenticates via OIDC, assumes hub roles, and optionally chains into spoke accounts to provision resources while ensuring exclusive state access.

```mermaid
sequenceDiagram
participant Dev as "Developer"
participant GHA as "GitHub Actions"
participant OIDC as "OIDC Provider"
participant HubPlan as "Hub Plan Role"
participant HubApply as "Hub Apply Role"
participant SpokePlan as "Spoke Plan Role"
participant SpokeApply as "Spoke Apply Role"
participant OSS as "OSS Backend"
participant OTS as "OTS Lock Table"
Dev->>GHA : "Open PR / Push to main"
GHA->>OIDC : "Request OIDC token"
OIDC-->>GHA : "STS token"
alt Pull Request
GHA->>HubPlan : "AssumeRole"
HubPlan->>SpokePlan : "AssumeRole"
SpokePlan->>OSS : "terraform init / plan"
OSS-->>SpokePlan : "State metadata"
else Production merge
GHA->>HubApply : "AssumeRole"
HubApply->>SpokeApply : "AssumeRole"
SpokeApply->>OTS : "Acquire lock"
OTS-->>SpokeApply : "Lock granted"
SpokeApply->>OSS : "terraform init / apply"
OSS-->>SpokeApply : "State updated"
SpokeApply->>OTS : "Release lock"
end
```

**Diagram sources**
- [terraform-reusable.yml](file://.github/workflows/terraform-reusable.yml)
- [bootstrap-01-cicd-foundation.yml](file://.github/workflows/bootstrap-01-cicd-foundation.yml)
- [main.tf](file://bootstrap/01-cicd-foundation/main.tf)
- [outputs.tf](file://bootstrap/01-cicd-foundation/outputs.tf)
- [main.tf](file://bootstrap/02-spoke-bootstrap/modules/spoke-roles/main.tf)

## Detailed Component Analysis

### OSS State Infrastructure
- Bucket configuration:
  - Versioning enabled to maintain immutable state history
  - SSE-KMS enforced for server-side encryption
  - Lifecycle rule to expire noncurrent object versions after a defined number of days
- Purpose:
  - Provides durable, encrypted storage for Terraform state
  - Supports safe migration and rollback via versioning

```mermaid
flowchart TD
Start(["Provision OSS Bucket"]) --> EnableVersioning["Enable Versioning"]
EnableVersioning --> SSEKMS["Configure SSE-KMS"]
SSEKMS --> Lifecycle["Define Lifecycle Rule<br/>Expire Noncurrent Versions"]
Lifecycle --> End(["Ready for State Storage"])
```

**Diagram sources**
- [main.tf](file://bootstrap/01-cicd-foundation/main.tf)

**Section sources**
- [main.tf](file://bootstrap/01-cicd-foundation/main.tf)

### OTS Distributed Locking
- OTS instance and table:
  - Instance type set to Capacity
  - Table with a string primary key and TTL set to infinite (-1)
  - Max version constrained to 1 for deterministic lock records
- Behavior:
  - Ensures mutual exclusion during apply operations
  - Prevents concurrent writes to the same state key

```mermaid
classDiagram
class OTSInstance {
+string name
+string instance_type
}
class OTSTable {
+string instance_name
+string table_name
+PrimaryKey primaryKey
+int time_to_live
+int max_version
}
class PrimaryKey {
+string name
+string type
}
OTSInstance "1" --> "1" OTSTable : "hosts"
OTSTable --> PrimaryKey : "has"
```

**Diagram sources**
- [main.tf](file://bootstrap/01-cicd-foundation/main.tf)

**Section sources**
- [main.tf](file://bootstrap/01-cicd-foundation/main.tf)

### Backend Configuration and State Migration
- Backend block:
  - Specifies OSS bucket, prefix, key, region
  - Configures OTS endpoint and table for distributed locking
- Migration procedure:
  - Obtain STS credentials for the CICD account
  - Initialize with OSS backend and migrate local state

```mermaid
sequenceDiagram
participant Operator as "Operator"
participant CLI as "aliyun CLI"
participant TF as "Terraform"
participant OSS as "OSS Backend"
Operator->>CLI : "AssumeRole to obtain STS"
CLI-->>Operator : "Temporary credentials"
Operator->>TF : "terraform init -migrate-state"
TF->>OSS : "Write initial state"
OSS-->>TF : "Migration complete"
```

**Diagram sources**
- [backend.tf.example](file://bootstrap/01-cicd-foundation/backend.tf.example)

**Section sources**
- [backend.tf.example](file://bootstrap/01-cicd-foundation/backend.tf.example)

### Security Controls and Access Policies
- OIDC provider:
  - GitHub Actions OIDC issuer configured with audience and conditions
- Hub roles:
  - Plan role for read-only operations on pull requests
  - Apply role for production merges with restricted environment
- Hub state access policy:
  - Permissions scoped to OSS bucket and OTS operations
  - Allow assume-role on spoke roles
- Spoke roles:
  - Plan role with read-only access
  - Apply role with administrator access (scope down per spoke as appropriate)

```mermaid
graph LR
OIDC["OIDC Provider"] --> Plan["GitHubActionsPlanRole"]
OIDC --> Apply["GitHubActionsApplyRole"]
Plan --> SpokePlan["Spoke Plan Role"]
Apply --> SpokeApply["Spoke Apply Role"]
Plan --> OSSPerm["OSS Read-Only"]
Apply --> OSSPerm
Apply --> OTSP["OTS Full Access"]
Apply --> AssumeSpoke["Assume Spoke Roles"]
```

**Diagram sources**
- [main.tf](file://bootstrap/01-cicd-foundation/main.tf)
- [main.tf](file://bootstrap/02-spoke-bootstrap/modules/spoke-roles/main.tf)

**Section sources**
- [main.tf](file://bootstrap/01-cicd-foundation/main.tf)
- [outputs.tf](file://bootstrap/01-cicd-foundation/outputs.tf)
- [main.tf](file://bootstrap/02-spoke-bootstrap/modules/spoke-roles/main.tf)

### Drift Detection and Integrity Verification
- Drift detection:
  - Schedule periodic plan-only runs to surface configuration drift
- Integrity verification:
  - Use plan artifacts and PR comments for review
  - Combine with scheduled checks to catch unauthorized changes

```mermaid
flowchart TD
A["Nightly Cron Trigger"] --> B["Reusable Workflow Plan Mode"]
B --> C["Terraform Plan"]
C --> D{"Drift Detected?"}
D --> |Yes| E["Publish Plan Artifact<br/>Post PR Comment"]
D --> |No| F["No Action"]
```

**Diagram sources**
- [.github/workflows/terraform-reusable.yml](file://.github/workflows/terraform-reusable.yml)
- [README.md](file://README.md)

**Section sources**
- [README.md](file://README.md)
- [.github/workflows/terraform-reusable.yml](file://.github/workflows/terraform-reusable.yml)

### Secure State Sharing Patterns
- Cross-account state access:
  - Hub roles assume spoke roles to operate in member accounts
  - Least privilege enforced via separate plan/apply roles
- Environment gating:
  - Apply jobs run only in protected environments with required reviewers

**Section sources**
- [main.tf](file://bootstrap/02-spoke-bootstrap/modules/spoke-roles/main.tf)
- [terraform-reusable.yml](file://.github/workflows/terraform-reusable.yml)

## Dependency Analysis
The state security relies on coordinated components across providers, roles, and backend configuration.

```mermaid
graph TB
Prov["Providers (cicd/mgmt)"] --> Infra["CICD Foundation Infrastructure"]
Infra --> OSS["OSS Bucket"]
Infra --> OTS["OTS Instance/Table"]
Infra --> OIDC["OIDC Provider"]
Infra --> HubRoles["Hub Roles"]
HubRoles --> SpokeRoles["Spoke Roles"]
Workflows["GitHub Actions Workflows"] --> OIDC
Workflows --> HubRoles
HubRoles --> OSS
HubRoles --> OTS
```

**Diagram sources**
- [providers.tf](file://bootstrap/01-cicd-foundation/providers.tf)
- [main.tf](file://bootstrap/01-cicd-foundation/main.tf)
- [main.tf](file://bootstrap/02-spoke-bootstrap/main.tf)
- [terraform-reusable.yml](file://.github/workflows/terraform-reusable.yml)

**Section sources**
- [providers.tf](file://bootstrap/01-cicd-foundation/providers.tf)
- [main.tf](file://bootstrap/01-cicd-foundation/main.tf)
- [main.tf](file://bootstrap/02-spoke-bootstrap/main.tf)
- [variables.tf](file://bootstrap/02-spoke-bootstrap/variables.tf)
- [terraform-reusable.yml](file://.github/workflows/terraform-reusable.yml)

## Performance Considerations
- OTS capacity sizing:
  - Evaluate expected lock contention; adjust instance type accordingly
- OSS lifecycle costs:
  - Noncurrent version expiration reduces storage costs over time
- Workflow concurrency:
  - Limit simultaneous apply operations to reduce OTS contention

## Troubleshooting Guide
- OIDC authentication failures:
  - Verify provider ARN, audience, and conditions match repository configuration
- Lock acquisition timeouts:
  - Confirm OTS table exists and permissions allow OTS operations
- State migration errors:
  - Ensure STS credentials are valid and backend block matches bucket naming and region
- Drift detection:
  - Review plan artifacts posted in PRs; investigate differences promptly

**Section sources**
- [outputs.tf](file://bootstrap/01-cicd-foundation/outputs.tf)
- [backend.tf.example](file://bootstrap/01-cicd-foundation/backend.tf.example)
- [terraform-reusable.yml](file://.github/workflows/terraform-reusable.yml)

## Conclusion
This repository demonstrates a robust, secure state management setup on Alibaba Cloud using OSS with KMS encryption and OTS-based distributed locking. Combined with OIDC-based identity, least-privilege roles, and automated drift detection, it provides a strong foundation for CI/CD operations across multiple accounts.

## Appendices

### Appendix A: Encryption Key Management
- Current state:
  - OSS SSE-KMS is enabled in the state infrastructure
  - KMS key configuration is marked as pending in the KMS stack
- Recommendations:
  - Define and scope KMS keys for state encryption
  - Enforce key rotation and audit logging
  - Scope key usage to the state bucket resource

**Section sources**
- [main.tf](file://bootstrap/01-cicd-foundation/main.tf)
- [main.tf](file://stacks/30-security-kms/main.tf)

### Appendix B: Access Control Policies for State Objects
- Hub state access policy:
  - Explicitly grants OSS read/write/delete/list/get bucket actions on the state bucket
  - Grants OTS operations across resources
  - Allows assume-role on spoke plan/apply roles
- Spoke roles:
  - Plan role attached to read-only access
  - Apply role attached to administrator access

**Section sources**
- [main.tf](file://bootstrap/01-cicd-foundation/main.tf)
- [main.tf](file://bootstrap/02-spoke-bootstrap/modules/spoke-roles/main.tf)

### Appendix C: Backup and Recovery Procedures
- Versioning-based recovery:
  - Use OSS versioning to restore previous state versions
- Lock table preservation:
  - Maintain OTS table for continued lock availability
- DR considerations:
  - Replicate state bucket across regions if required
  - Automate key rotation and cross-region replication with appropriate IAM and KMS policies

**Section sources**
- [main.tf](file://bootstrap/01-cicd-foundation/main.tf)