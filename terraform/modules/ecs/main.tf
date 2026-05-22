data "aws_region" "current" {}

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = "${var.name_prefix}.local"
  description = "Service discovery namespace"
  vpc         = var.vpc_id
}

resource "aws_service_discovery_service" "api" {
  name = "api"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.name_prefix}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs.api.cpu
  memory                   = var.ecs.api.memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "log_router"
      image     = "public.ecr.aws/aws-observability/aws-for-fluent-bit:stable"
      essential = true
      firelensConfiguration = {
        type = "fluentbit"
        options = {
          "enable-ecs-log-metadata" = "true"
        }
      }
      environment = [
        { name = "ENVIRONMENT", value = var.name_prefix },
        { name = "GRAFANA_LOKI_HOST", value = replace(replace(var.grafana_cloud.loki_url, "https://", ""), "/loki/api/v1/push", "") }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "firelens"
        }
      }
    },
    {
      name      = "api"
      image     = var.container_images.api
      essential = true
      portMappings = [
        {
          containerPort = var.ecs.api.container_port
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "APP_ENV", value = var.name_prefix },
        { name = "REDIS_HOST", value = var.redis_endpoint },
        { name = "REDIS_PORT", value = tostring(var.redis_port) }
      ]
      secrets = [
        { name = "REDIS_AUTH_TOKEN", valueFrom = var.secrets_arns["redis_auth_token"] },
        { name = "SLACK_WEBHOOK", valueFrom = var.secrets_arns["slack_webhook"] }
      ]
      logConfiguration = {
        logDriver = "awsfirelens"
        options = {
          Name        = "loki"
          Host        = replace(replace(var.grafana_cloud.loki_url, "https://", ""), "/loki/api/v1/push", "")
          tls         = "on"
          port        = "443"
          uri         = "/loki/api/v1/push"
          http_user   = var.grafana_cloud_auth.loki_user
          labels      = "service=api,env=${var.name_prefix}"
          line_format = "json"
        }
        secretOptions = [
          { name = "http_passwd", valueFrom = var.secrets_arns["grafana_api_key"] }
        ]
      }
      healthCheck = {
        command     = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz').read()\""]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 20
      }
    }
  ])
}

resource "aws_ecs_service" "api" {
  name            = "${var.name_prefix}-api"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.api.arn
  launch_type     = "FARGATE"
  desired_count   = var.ecs.api.desired_count

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "api"
    container_port   = var.ecs.api.container_port
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  service_registries {
    registry_arn = aws_service_discovery_service.api.arn
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_appautoscaling_target" "api" {
  max_capacity       = var.ecs.api.max_capacity
  min_capacity       = var.ecs.api.min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "api_cpu" {
  name               = "${var.name_prefix}-api-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api.resource_id
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

locals {
  worker_defs = {
    analyzer = {
      image = var.container_images.analyzer
      cmd   = ["python", "-m", "sre_platform.workers.analyzer"]
    }
    planner = {
      image = var.container_images.planner
      cmd   = ["python", "-m", "sre_platform.workers.planner"]
    }
    executor = {
      image = var.container_images.executor
      cmd   = ["python", "-m", "sre_platform.workers.executor"]
    }
  }
}

resource "aws_ecs_task_definition" "worker" {
  for_each = local.worker_defs

  family                   = "${var.name_prefix}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs.workers.cpu
  memory                   = var.ecs.workers.memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "log_router"
      image     = "public.ecr.aws/aws-observability/aws-for-fluent-bit:stable"
      essential = true
      firelensConfiguration = {
        type = "fluentbit"
        options = {
          "enable-ecs-log-metadata" = "true"
        }
      }
      environment = [
        { name = "ENVIRONMENT", value = var.name_prefix },
        { name = "GRAFANA_LOKI_HOST", value = replace(replace(var.grafana_cloud.loki_url, "https://", ""), "/loki/api/v1/push", "") }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "firelens"
        }
      }
    },
    {
      name      = each.key
      image     = each.value.image
      essential = true
      command   = each.value.cmd
      environment = [
        { name = "APP_ENV", value = var.name_prefix },
        { name = "REDIS_HOST", value = var.redis_endpoint },
        { name = "REDIS_PORT", value = tostring(var.redis_port) },
        { name = "GRAFANA_STACK_SLUG", value = var.grafana_cloud.stack_slug }
      ]
      secrets = [
        { name = "REDIS_AUTH_TOKEN", valueFrom = var.secrets_arns["redis_auth_token"] },
        { name = "OPENAI_API_KEY", valueFrom = var.secrets_arns["openai_api_key"] },
        { name = "GROQ_API_KEY", valueFrom = var.secrets_arns["groq_api_key"] },
        { name = "SLACK_WEBHOOK", valueFrom = var.secrets_arns["slack_webhook"] },
        { name = "JIRA_TOKEN", valueFrom = var.secrets_arns["jira_token"] },
        { name = "GITHUB_TOKEN", valueFrom = var.secrets_arns["github_token"] }
      ]
      logConfiguration = {
        logDriver = "awsfirelens"
        options = {
          Name        = "loki"
          Host        = replace(replace(var.grafana_cloud.loki_url, "https://", ""), "/loki/api/v1/push", "")
          tls         = "on"
          port        = "443"
          uri         = "/loki/api/v1/push"
          http_user   = var.grafana_cloud_auth.loki_user
          labels      = "service=${each.key},env=${var.name_prefix}"
          line_format = "json"
        }
        secretOptions = [
          { name = "http_passwd", valueFrom = var.secrets_arns["grafana_api_key"] }
        ]
      }
    }
  ])
}

resource "aws_ecs_task_definition" "alloy" {
  family                   = "${var.name_prefix}-alloy"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "redis_exporter"
      image     = "oliver006/redis_exporter:v1.63.0"
      essential = true
      environment = [
        { name = "REDIS_ADDR", value = "redis://${var.redis_endpoint}:${tostring(var.redis_port)}" }
      ]
      secrets = [
        { name = "REDIS_PASSWORD", valueFrom = var.secrets_arns["redis_auth_token"] }
      ]
      portMappings = [{ containerPort = 9121, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "redis-exporter"
        }
      }
    },
    {
      name      = "alloy"
      image     = var.container_images.alloy
      essential = true
      command   = ["run", "/etc/alloy/config.river", "--server.http.listen-addr=0.0.0.0:12345"]
      environment = [
        { name = "GRAFANA_PROM_REMOTE_WRITE_URL", value = var.grafana_cloud.prometheus_remote_write },
        { name = "GRAFANA_PROM_USER", value = var.grafana_cloud_auth.prom_user },
        { name = "API_METRICS_TARGET", value = "api.${var.name_prefix}.local:8080" }
      ]
      secrets = [
        { name = "GRAFANA_API_KEY", valueFrom = var.secrets_arns["grafana_api_key"] }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "alloy"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "alloy" {
  name            = "${var.name_prefix}-alloy"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.alloy.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
}

resource "aws_ecs_service" "worker" {
  for_each        = local.worker_defs
  name            = "${var.name_prefix}-${each.key}"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.worker[each.key].arn
  launch_type     = "FARGATE"
  desired_count   = var.ecs.workers.desired_count

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_appautoscaling_target" "worker" {
  for_each           = local.worker_defs
  max_capacity       = var.ecs.workers.max_capacity
  min_capacity       = var.ecs.workers.min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.worker[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "worker_cpu" {
  for_each           = local.worker_defs
  name               = "${var.name_prefix}-${each.key}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.worker[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 65
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "api_service_name" {
  value = aws_ecs_service.api.name
}
