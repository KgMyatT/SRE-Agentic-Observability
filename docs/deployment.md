# Deployment Guide (AWS)

## Prereqs

- Terraform `>= 1.6`
- AWS account + CLI credentials
- A Grafana Cloud stack:
  - Loki endpoint URL
  - Prometheus remote_write URL
  - Prometheus username + Loki username
  - API key (store in Secrets Manager)

## 1) Bootstrap remote state (one-time)

From `terraform/backend`:

- `terraform init`
- `terraform apply -var aws_region=us-east-1 -var name_prefix=agentic-sre`

Update `terraform/envs/*/backend.hcl` to match the printed `bucket_name` and `dynamodb_table_name`.

## 2) Create Secrets Manager secrets (names only created by Terraform)

Terraform creates empty Secrets Manager **containers**. Populate them out-of-band:

- `agentic-sre-<env>/openai_api_key`
- `agentic-sre-<env>/groq_api_key`
- `agentic-sre-<env>/grafana_api_key`
- `agentic-sre-<env>/slack_webhook`
- `agentic-sre-<env>/jira_token`
- `agentic-sre-<env>/github_token`
- `agentic-sre-<env>/redis_auth_token`

Use AWS Console or:
- `aws secretsmanager put-secret-value --secret-id <arn-or-name> --secret-string <value>`

## 3) Build and push images (ECR)

Create ECR repos (recommended):
- `agentic-sre-api`
- `agentic-sre-worker`
- `agentic-sre-alloy`

Then build/push:

- `docker build -f services/python/Dockerfile.api -t <acct>.dkr.ecr.<region>.amazonaws.com/agentic-sre-api:<tag> services/python`
- `docker build -f services/python/Dockerfile.worker -t <acct>.dkr.ecr.<region>.amazonaws.com/agentic-sre-worker:<tag> services/python`
- `docker build -f services/alloy/Dockerfile -t <acct>.dkr.ecr.<region>.amazonaws.com/agentic-sre-alloy:<tag> services/alloy`

## 4) Deploy an environment

From `terraform/envs/dev`:

- `terraform init -backend-config=backend.hcl`
- `terraform plan`
- `terraform apply`

## 5) Verify

- ALB endpoint: `terraform output alb_dns_name`
- API health: `curl http://<alb_dns_name>/healthz`
- API metrics: `curl http://<alb_dns_name>/metrics`

## Rollback strategy

- ECS uses rolling deployments. Roll back by re-pointing the service to a previous image tag and re-applying.
- Terraform-managed changes: revert commit and re-apply.

