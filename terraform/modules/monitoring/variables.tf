variable "name_prefix" { type = string }
variable "sns_email_subscription" {
  description = "Optional email to subscribe to the alerts SNS topic."
  type        = string
  default     = ""
}

variable "ecs_cluster_name" { type = string }
variable "api_service_name" { type = string }
variable "redis_replication_group_id" { type = string }
variable "alarm_actions" {
  description = "List of ARNs to notify (SNS topic ARN recommended)."
  type        = list(string)
  default     = []
}

