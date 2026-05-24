# Shared: ECR (bootstrap)

These ECR repositories are **shared** across environments and should not be destroyed during normal env lifecycle operations.

Why this exists:
- `terraform/envs/*` stacks can be created/destroyed safely (ephemeral envs).
- Container registries should be long-lived (keeps images for rollbacks + reduces churn).

## Apply

Run with its own backend (recommended) or locally for a first bootstrap:

- `terraform init`
- `terraform apply -var aws_region=us-east-1 -var project_name=agentic-sre`

## Outputs

- `repository_urls` (use in CI/CD to tag/push)

