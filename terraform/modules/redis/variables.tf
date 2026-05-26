variable "name_prefix" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "redis_security_group_id" { type = string }
variable "auth_token" {
  type      = string
  sensitive = true
}
variable "redis" {
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
