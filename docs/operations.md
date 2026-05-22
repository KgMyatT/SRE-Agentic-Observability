# Production Operations

## Queues

Redis lists:
- `queue:events` → Analyzer
- `queue:findings` → Planner
- `queue:plans` → Executor
- `queue:executions` (results)
- DLQ: `dlq:queue:*`

## Health checks

- API: `/healthz`
- ALB health check uses `/healthz`

## Observability

- Logs: ECS → FireLens (Fluent Bit) → Grafana Cloud Loki (API key via Secrets Manager)
- Metrics: Alloy scrapes:
  - API: `/metrics`
  - Redis: `redis_exporter` inside the Alloy task
  - Remote write to Grafana Cloud Prometheus

Starter dashboard:
- `observability/dashboards/agentic-sre-overview.json`

## Alerting

AWS CloudWatch alarms (starter):
- ECS API CPU high
- Redis engine CPU high

For Slack notifications, prefer Grafana Alerting (Loki/Prometheus rules) with a Slack contact point.

## Scaling knobs

- API: adjust `var.ecs.api.*` in `terraform/envs/<env>/main.tf`
- Workers: adjust `var.ecs.workers.*`
- Redis: adjust `var.redis.node_type` and cluster sizing

## Cost controls

- Single NAT gateway (startup-friendly; not HA across AZs)
- Log retention: CloudWatch log group retains 14 days (adjust in `terraform/modules/cloudwatch`)
- Prefer smaller Fargate tasks + autoscaling

