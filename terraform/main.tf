locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

module "vpc" {
  source = "./modules/vpc"

  name_prefix = local.name_prefix
}

module "security_groups" {
  source = "./modules/security-groups"

  name_prefix          = local.name_prefix
  vpc_id               = module.vpc.vpc_id
  public_subnet_cidrs  = module.vpc.public_subnet_cidrs
  private_subnet_cidrs = module.vpc.private_subnet_cidrs
  api_container_port   = var.ecs.api.container_port
}

module "iam" {
  source = "./modules/iam"

  name_prefix = local.name_prefix
}

module "secrets_manager" {
  source = "./modules/secrets-manager"

  name_prefix  = local.name_prefix
  secret_names = var.secrets
}

module "cloudwatch" {
  source = "./modules/cloudwatch"

  name_prefix = local.name_prefix
}

module "alb" {
  source = "./modules/alb"

  name_prefix           = local.name_prefix
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_sg_id
  api_container_port    = var.ecs.api.container_port
}

module "redis" {
  source = "./modules/redis"

  name_prefix             = local.name_prefix
  private_subnet_ids      = module.vpc.private_subnet_ids
  redis_security_group_id = module.security_groups.redis_sg_id
  redis                   = var.redis
  auth_token_secret_arn   = module.secrets_manager.secret_arns.redis_auth_token
}

module "ecs" {
  source = "./modules/ecs"

  name_prefix                = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  ecs_security_group_id      = module.security_groups.ecs_sg_id
  task_execution_role_arn    = module.iam.ecs_task_execution_role_arn
  task_role_arn              = module.iam.ecs_task_role_arn
  log_group_name             = module.cloudwatch.log_group_name
  alb_target_group_arn       = module.alb.target_group_arn
  alb_listener_arn           = module.alb.listener_arn
  api_listener_rule_priority = 100

  container_images = var.container_images
  ecs              = var.ecs

  secrets_arns = merge(
    module.secrets_manager.secret_arns,
    {
      redis_auth_token = module.secrets_manager.secret_arns.redis_auth_token
    }
  )

  redis_endpoint = module.redis.primary_endpoint_address
  redis_port     = module.redis.port

  grafana_cloud      = var.grafana_cloud
  grafana_cloud_auth = var.grafana_cloud_auth
}

module "monitoring" {
  source = "./modules/monitoring"

  name_prefix                = local.name_prefix
  ecs_cluster_name           = module.ecs.cluster_name
  api_service_name           = module.ecs.api_service_name
  redis_replication_group_id = module.redis.replication_group_id
}
