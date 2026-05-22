variable "project_name" {
  description = "Project name used for resource naming and tagging."
  type        = string
}

variable "environment" {
  description = "Environment name (dev|staging|prod)."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "extra_tags" {
  description = "Additional tags to apply to resources."
  type        = map(string)
  default     = {}
}

variable "grafana_cloud" {
  description = "Grafana Cloud settings (no secrets)."
  type = object({
    stack_slug              = string
    loki_url                = string
    prometheus_remote_write = string
  })
}

variable "grafana_cloud_auth" {
  description = "Grafana Cloud auth usernames (no secrets)."
  type = object({
    loki_user = string
    prom_user = string
  })
  default = {
    loki_user = "CHANGE_ME"
    prom_user = "CHANGE_ME"
  }
}

variable "container_images" {
  description = "Container images (tagged) for services."
  type = object({
    api      = string
    analyzer = string
    planner  = string
    executor = string
    alloy    = string
  })
}

variable "ecs" {
  description = "ECS sizing and scaling knobs."
  type = object({
    api = object({
      cpu            = number
      memory         = number
      desired_count  = number
      min_capacity   = number
      max_capacity   = number
      container_port = number
    })
    workers = object({
      cpu           = number
      memory        = number
      desired_count = number
      min_capacity  = number
      max_capacity  = number
    })
  })
}

variable "redis" {
  description = "ElastiCache Redis settings."
  type = object({
    node_type           = string
    engine_version      = string
    num_cache_clusters  = number
    snapshot_retention  = number
    transit_encryption  = bool
    at_rest_encryption  = bool
    auth_token_rotation = bool
    maintenance_window  = string
    snapshot_window     = string
  })
}

variable "secrets" {
  description = "Names (not values) of Secrets Manager secrets to reference."
  type = object({
    openai_api_key   = string
    groq_api_key     = string
    grafana_api_key  = string
    slack_webhook    = string
    jira_token       = string
    github_token     = string
    redis_auth_token = string
  })
}
