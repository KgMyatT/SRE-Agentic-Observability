from __future__ import annotations

import asyncio

import redis.asyncio as redis

from sre_platform.logging import logger, setup_logging
from sre_platform.queue import QueueNames, RedisQueue, run_worker_loop
from sre_platform.settings import Settings


async def main() -> None:
    settings = Settings()
    setup_logging("analyzer")
    log = logger(__name__, "analyzer")

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
        event = msg.get("payload", {})
        finding = {
            "source": event.get("source", "unknown"),
            "severity": event.get("severity", "info"),
            "summary": event.get("message", "no message"),
            "raw": event,
        }
        out = dict(msg)
        out["type"] = "finding"
        out["payload"] = finding
        await queue.push(QueueNames.findings, out)
        log.info("analyzed", extra={"event_id": msg.get("id"), "severity": finding["severity"]})

    await run_worker_loop(queue=queue, in_queue=QueueNames.events, handler=handle, concurrency=8)


if __name__ == "__main__":
    asyncio.run(main())

