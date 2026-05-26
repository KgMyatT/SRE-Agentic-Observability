resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name_prefix}-redis-subnets"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name_prefix}-redis"
  description          = "Redis for agentic SRE queues"
  engine               = "redis"
  engine_version       = var.redis.engine_version
  node_type            = var.redis.node_type
  num_cache_clusters   = var.redis.num_cache_clusters
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [var.redis_security_group_id]

  at_rest_encryption_enabled = var.redis.at_rest_encryption
  transit_encryption_enabled = var.redis.transit_encryption
  auth_token                 = trimspace(var.auth_token)

  snapshot_retention_limit = var.redis.snapshot_retention
  snapshot_window          = var.redis.snapshot_window
  maintenance_window       = var.redis.maintenance_window

  automatic_failover_enabled = false
  multi_az_enabled           = false
}

output "primary_endpoint_address" {
  value = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "port" { value = aws_elasticache_replication_group.this.port }

output "replication_group_id" {
  value = aws_elasticache_replication_group.this.replication_group_id
}
