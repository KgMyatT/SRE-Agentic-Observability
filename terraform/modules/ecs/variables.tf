variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "ecs_security_group_id" { type = string }
variable "task_execution_role_arn" { type = string }
variable "task_role_arn" { type = string }
variable "log_group_name" { type = string }

variable "alb_target_group_arn" { type = string }

variable "container_images" {
  type = object({
    api      = string
    analyzer = string
    planner  = string
    executor = string
    alloy    = string
  })
}

variable "ecs" {
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

variable "secrets_arns" {
  type = map(string)
}

variable "redis_endpoint" { type = string }
variable "redis_port" { type = number }

variable "grafana_cloud" {
  type = object({
    stack_slug              = string
    loki_url                = string
    prometheus_remote_write = string
  })
}

variable "grafana_cloud_auth" {
  type = object({
    loki_user = string
    prom_user = string
  })
}
