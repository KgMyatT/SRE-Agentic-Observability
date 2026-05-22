from __future__ import annotations

import asyncio
import json
import os
import time
import uuid
from dataclasses import dataclass
from typing import Any

import redis.asyncio as redis


@dataclass(frozen=True)
class QueueNames:
    events: str = "queue:events"
    findings: str = "queue:findings"
    plans: str = "queue:plans"
    executions: str = "queue:executions"


def _now_ms() -> int:
    return int(time.time() * 1000)


def make_message(msg_type: str, payload: dict[str, Any], attempts: int = 0) -> dict[str, Any]:
    return {
        "id": str(uuid.uuid4()),
        "type": msg_type,
        "payload": payload,
        "attempts": attempts,
        "created_at_ms": _now_ms(),
    }


class RedisQueue:
    def __init__(self, client: redis.Redis, dlq_prefix: str = "dlq:") -> None:
        self.client = client
        self.dlq_prefix = dlq_prefix

    async def push(self, queue: str, message: dict[str, Any]) -> None:
        await self.client.lpush(queue, json.dumps(message))

    async def pop_blocking(self, queue: str, timeout_s: int = 30) -> dict[str, Any] | None:
        item = await self.client.brpop(queue, timeout=timeout_s)
        if not item:
            return None
        _, raw = item
        return json.loads(raw)

    async def dead_letter(self, queue: str, message: dict[str, Any], reason: str) -> None:
        dlq_name = f"{self.dlq_prefix}{queue}"
        msg = dict(message)
        msg["dlq_reason"] = reason
        msg["dlq_at_ms"] = _now_ms()
        await self.push(dlq_name, msg)


async def connect_redis(host: str, port: int, auth_token: str) -> redis.Redis:
    return redis.Redis(
        host=host,
        port=port,
        password=auth_token if auth_token else None,
        ssl=bool(int(os.getenv("REDIS_SSL", "0"))),
        socket_timeout=5,
        socket_connect_timeout=5,
        retry_on_timeout=True,
        health_check_interval=30,
    )


async def run_worker_loop(
    *,
    queue: RedisQueue,
    in_queue: str,
    handler,
    max_attempts: int = 5,
    backoff_base_s: float = 0.5,
    concurrency: int = 8,
) -> None:
    sem = asyncio.Semaphore(concurrency)

    async def _process(msg: dict[str, Any]) -> None:
        async with sem:
            attempts = int(msg.get("attempts", 0))
            try:
                await handler(msg)
            except Exception as exc:  # noqa: BLE001
                attempts += 1
                msg["attempts"] = attempts
                if attempts >= max_attempts:
                    await queue.dead_letter(in_queue, msg, reason=f"max_attempts_exceeded: {exc}")
                    return
                sleep_s = backoff_base_s * (2 ** (attempts - 1))
                await asyncio.sleep(min(sleep_s, 30))
                await queue.push(in_queue, msg)

    while True:
        msg = await queue.pop_blocking(in_queue, timeout_s=20)
        if msg is None:
            continue
        asyncio.create_task(_process(msg))
