This repository is an Infrastructure-as-Code (IaC) project built entirely with Terraform and GitHub Actions — there is no application code, so traditional error handling patterns (sentinel errors, middleware, panic/recover) do not apply. Instead, error handling is implemented at two layers:

1. **Terraform input validation via `error_message`**
   Every module's `variables.tf` uses the `validation` block with descriptive `error_message` strings to fail fast on invalid inputs. Examples include account name prefix rules, RAM user naming constraints, VPC baseline requirements, guardrails risk levels, and security preference settings. These messages are surfaced directly in `terraform plan`/`apply` output and guide users toward correct configuration.

2. **GitHub Actions workflow orchestration**
   The reusable workflow `.github/workflows/terraform-reusable.yml` drives the CI pipeline. It does not implement custom error handling or retry logic; it relies on Terraform's native exit codes — a non-zero exit from `terraform plan` or `terraform apply` causes the job step to fail, which marks the entire workflow run as failed. Plan outputs are uploaded as artifacts and posted as PR comments for visibility, but failures are not programmatically parsed or transformed.

There is no centralized error type system, no structured logging framework, no retry/backoff strategy, and no recovery mechanisms. Errors are purely declarative (Terraform validation) and procedural (workflow failure propagation).