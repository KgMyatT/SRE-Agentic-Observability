output "alb_dns_name" {
  description = "ALB DNS name for the API."
  value       = module.alb.dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs.cluster_name
}

output "redis_primary_endpoint" {
  description = "Redis primary endpoint address."
  value       = module.redis.primary_endpoint_address
}

