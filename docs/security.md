# Security Best Practices

- Secrets:
  - Use AWS Secrets Manager only (no `.env` committed)
  - Limit `secretsmanager:GetSecretValue` permissions to specific secret ARNs (tighten the IAM module for prod)
- Network:
  - Redis in private subnets only
  - Redis SG allows ingress only from ECS SG
- Encryption:
  - ElastiCache at-rest + in-transit encryption enabled
  - Terraform state bucket uses SSE and public access blocks
- IAM:
  - Separate task execution role vs task role
  - Use OIDC for GitHub Actions (no long-lived AWS keys)
- Containers:
  - Use minimal images
  - Add image scanning (ECR scan-on-push) and enforce in CI

