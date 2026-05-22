from __future__ import annotations

import asyncio

import redis.asyncio as redis

from sre_platform.integrations.slack import post_webhook
from sre_platform.logging import logger, setup_logging
from sre_platform.queue import QueueNames, RedisQueue, run_worker_loop
from sre_platform.settings import Settings


async def main() -> None:
    settings = Settings()
    setup_logging("executor")
    log = logger(__name__, "executor")

    client = redis.Redis(
        host=settings.redis_host,
        port=settings.redis_port,
        password=settings.redis_auth_token or None,
        socket_timeout=5,
        socket_connect_timeout=5,
        retry_on_timeout=True,
        health_check_interval=30,
    )
    queue = RedisQueue(client)

    async def handle(msg: dict) -> None:
        plan = msg.get("payload", {})
        severity = plan.get("severity", "info")
        title = plan.get("title", "Incident plan")
        steps = plan.get("steps", [])

        text = f"*{severity.upper()}* {title}\n" + "\n".join([f"- {s}" for s in steps])
        post_webhook(settings.slack_webhook, text)

        out = dict(msg)
        out["type"] = "execution"
        out["payload"] = {"status": "notified", "channel": "slack", "severity": severity}
        await queue.push(QueueNames.executions, out)
        log.info("executed", extra={"plan_id": msg.get("id"), "severity": severity})

    await run_worker_loop(queue=queue, in_queue=QueueNames.plans, handler=handle, concurrency=4)


if __name__ == "__main__":
    asyncio.run(main())

