# Grafana Cloud

This repo intentionally keeps Grafana Cloud provisioning lightweight.

Included assets:
- `observability/alloy/` (Alloy configuration for metrics remote_write)
- `observability/dashboards/` (starter dashboard JSON)

Production options:
- Manage dashboards/alerting with the Grafana Terraform provider (recommended).
- Import dashboards via CI using the Grafana HTTP API.

