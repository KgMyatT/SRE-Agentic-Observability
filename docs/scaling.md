# Scaling Roadmap

Current limitations (startup-friendly defaults):
- Single NAT gateway (not AZ-HA)
- Redis is a single-node replication group (no Multi-AZ / failover)
- Workers are stateless and scale by ECS desired count

Next steps:
- Add Multi-AZ Redis + automatic failover
- Add second NAT gateway (per-AZ) for HA
- Add queue visibility + backpressure (stream + consumer groups)
- Add structured incident store (DynamoDB/Postgres) for audit/reporting
- Add auth for API (Cognito / OIDC) and WAF

