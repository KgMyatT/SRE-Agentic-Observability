variable "name_prefix" { type = string }
variable "secret_names" {
  type = object({
    openai_api_key   = string
    groq_api_key     = string
    grafana_api_key  = string
    slack_webhook    = string
    jira_token       = string
    github_token     = string
    redis_auth_token = string
  })
}

