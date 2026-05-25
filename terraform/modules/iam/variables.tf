variable "name_prefix" {
  type = string
}

variable "secret_arns" {
  description = "Map of Secrets Manager secret ARNs that ECS tasks may read."
  type        = map(string)
}

variable "log_group_arn" {
  description = "CloudWatch log group ARN for ECS task logging."
  type        = string
}
