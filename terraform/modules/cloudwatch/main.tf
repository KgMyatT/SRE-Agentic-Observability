resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/${var.name_prefix}/ecs"
  retention_in_days = 14
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.ecs.name
}

output "log_group_arn" {
  value = aws_cloudwatch_log_group.ecs.arn
}
