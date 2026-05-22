from __future__ import annotations

import json
import requests


def post_webhook(webhook_url: str, text: str) -> None:
    if not webhook_url:
        return
    requests.post(webhook_url, data=json.dumps({"text": text}), timeout=10, headers={"Content-Type": "application/json"})

