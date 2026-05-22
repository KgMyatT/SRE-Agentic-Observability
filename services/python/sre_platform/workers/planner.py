from __future__ import annotations

import asyncio

import redis.asyncio as redis

from sre_platform.logging import logger, setup_logging
from sre_platform.queue import QueueNames, RedisQueue, run_worker_loop
from sre_platform.settings import Settings


async def main() -> None:
    settings = Settings()
    setup_logging("planner")
    log = logger(__name__, "planner")

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
        finding = msg.get("payload", {})
        plan = {
            "title": f"Investigate: {finding.get('summary', 'incident')}",
            "steps": [
                "Confirm blast radius and customer impact",
                "Check recent deploys and feature flags",
                "Inspect error budgets and saturation signals",
                "Mitigate (rollback / scale / config change) if needed",
                "Create post-incident review items",
            ],
            "severity": finding.get("severity", "info"),
            "finding": finding,
        }
        out = dict(msg)
        out["type"] = "plan"
        out["payload"] = plan
        await queue.push(QueueNames.plans, out)
        log.info("planned", extra={"finding_id": msg.get("id"), "severity": plan["severity"]})

    await run_worker_loop(queue=queue, in_queue=QueueNames.findings, handler=handle, concurrency=6)


if __name__ == "__main__":
    asyncio.run(main())

