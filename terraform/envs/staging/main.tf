terraform {
  required_version = ">= 1.6.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

module "stack" {
  source       = "../../"
  project_name = "agentic-sre"
  environment  = "staging"
  aws_region   = "us-east-1"

  grafana_cloud = {
    stack_slug              = "CHANGE_ME"
    loki_url                = "https://logs-prod-XXX.grafana.net/loki/api/v1/push"
    prometheus_remote_write = "https://prometheus-prod-XXX.grafana.net/api/prom/push"
  }

  container_images = {
    api      = "CHANGE_ME.dkr.ecr.us-east-1.amazonaws.com/agentic-sre-api:staging"
    analyzer = "CHANGE_ME.dkr.ecr.us-east-1.amazonaws.com/agentic-sre-worker:staging"
    planner  = "CHANGE_ME.dkr.ecr.us-east-1.amazonaws.com/agentic-sre-worker:staging"
    executor = "CHANGE_ME.dkr.ecr.us-east-1.amazonaws.com/agentic-sre-worker:staging"
    alloy    = "CHANGE_ME.dkr.ecr.us-east-1.amazonaws.com/agentic-sre-alloy:staging"
  }

  ecs = {
    api = {
      cpu            = 512
      memory         = 1024
      desired_count  = 2
      min_capacity   = 2
      max_capacity   = 6
      container_port = 8080
    }
    workers = {
      cpu           = 256
      memory        = 512
      desired_count = 2
      min_capacity  = 2
      max_capacity  = 6
    }
  }

  redis = {
    node_type           = "cache.t4g.small"
    engine_version      = "7.1"
    num_cache_clusters  = 1
    snapshot_retention  = 7
    transit_encryption  = true
    at_rest_encryption  = true
    auth_token_rotation = false
    maintenance_window  = "sun:05:00-sun:06:00"
    snapshot_window     = "03:00-04:00"
  }

  secrets = {
    openai_api_key   = "openai_api_key"
    groq_api_key     = "groq_api_key"
    grafana_api_key  = "grafana_api_key"
    slack_webhook    = "slack_webhook"
    jira_token       = "jira_token"
    github_token     = "github_token"
    redis_auth_token = "redis_auth_token"
  }
}
