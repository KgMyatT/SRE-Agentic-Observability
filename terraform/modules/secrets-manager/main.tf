resource "aws_secretsmanager_secret" "this" {
  for_each = {
    openai_api_key   = var.secret_names.openai_api_key
    groq_api_key     = var.secret_names.groq_api_key
    grafana_api_key  = var.secret_names.grafana_api_key
    slack_webhook    = var.secret_names.slack_webhook
    jira_token       = var.secret_names.jira_token
    github_token     = var.secret_names.github_token
    redis_auth_token = var.secret_names.redis_auth_token
  }

  name = "${var.name_prefix}/${each.value}"

  recovery_window_in_days = 7
}

output "secret_arns" {
  value = {
    openai_api_key   = aws_secretsmanager_secret.this["openai_api_key"].arn
    groq_api_key     = aws_secretsmanager_secret.this["groq_api_key"].arn
    grafana_api_key  = aws_secretsmanager_secret.this["grafana_api_key"].arn
    slack_webhook    = aws_secretsmanager_secret.this["slack_webhook"].arn
    jira_token       = aws_secretsmanager_secret.this["jira_token"].arn
    github_token     = aws_secretsmanager_secret.this["github_token"].arn
    redis_auth_token = aws_secretsmanager_secret.this["redis_auth_token"].arn
  }
}

