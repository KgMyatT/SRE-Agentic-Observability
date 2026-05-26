# Agentic AI SRE Platform (AWS + Terraform + ECS)

Production-ready starter platform for AI-powered incident response:

Logs/Metrics/Events → Loki/Prometheus (Grafana Cloud) → Redis queue → AI workers → Slack/Jira/GitHub incidents → Incident report.

## What’s in this repo

- `terraform/`: modular AWS infra (VPC, ALB, ECS Fargate, ElastiCache Redis, Secrets Manager, CloudWatch alarms)
- `services/python/`: Flask API + 3 AI workers (Analyzer/Planner/Executor)
- `services/alloy/`: Grafana Alloy container for Prometheus remote_write (scrapes API + redis_exporter)
- `observability/`: starter Alloy config + Fluent Bit sample + dashboard JSON
- `.github/workflows/`: CI/CD + security scanning

## Quickstart (local)

1. Run Redis + services:
   - `docker compose -f docker-compose.local.yml up --build`
2. Send an event:
   - `curl -X POST http://localhost:8080/ingest -H "content-type: application/json" -d "{\"source\":\"app\",\"severity\":\"high\",\"message\":\"5xx spike\"}"`

## Quickstart (AWS)

See:
- `docs/deployment.md`
- `docs/operations.md`
- `docs/troubleshooting.md`

comit-readmi