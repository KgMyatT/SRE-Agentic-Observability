# Troubleshooting

## Terraform init fails (backend)

- Confirm `terraform/envs/<env>/backend.hcl` bucket/table exist.
- Confirm your AWS principal can read/write the S3 bucket and lock table.

## ECS tasks stuck in `PROVISIONING` / `PENDING`

Common causes:
- Subnets lack NAT route (private route table/NAT gateway misconfigured)
- Security group blocks egress (ECR pull, Grafana endpoints)
- Missing Secrets Manager values (secret exists but has no current version)

## Logs not showing in Loki

Checklist:
- `grafana_api_key` secret has a value
- `grafana_cloud_auth.loki_user` is correct
- `grafana_cloud.loki_url` matches your stack (must end with `/loki/api/v1/push`)
- FireLens container running in task definition

## Metrics not showing

Checklist:
- Alloy task running
- `grafana_cloud_auth.prom_user` correct
- `grafana_cloud.prometheus_remote_write` correct
- API is registered in Cloud Map (`api.<name_prefix>.local`)

