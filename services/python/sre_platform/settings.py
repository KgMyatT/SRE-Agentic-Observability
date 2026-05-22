from __future__ import annotations

import os


def env(name: str, default: str | None = None) -> str:
    value = os.getenv(name, default)
    if value is None or value == "":
        raise RuntimeError(f"Missing required env var: {name}")
    return value


class Settings:
    def __init__(self) -> None:
        self.app_env = os.getenv("APP_ENV", "local")
        self.redis_host = env("REDIS_HOST", "localhost")
        self.redis_port = int(os.getenv("REDIS_PORT", "6379"))
        self.redis_auth_token = env("REDIS_AUTH_TOKEN", "")
        self.slack_webhook = os.getenv("SLACK_WEBHOOK", "")
        self.openai_api_key = os.getenv("OPENAI_API_KEY", "")
        self.groq_api_key = os.getenv("GROQ_API_KEY", "")
        self.jira_token = os.getenv("JIRA_TOKEN", "")
        self.github_token = os.getenv("GITHUB_TOKEN", "")

