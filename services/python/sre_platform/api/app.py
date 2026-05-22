from __future__ import annotations

import asyncio
from flask import Flask, jsonify, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

from sre_platform.logging import logger, setup_logging
from sre_platform.queue import QueueNames, RedisQueue, make_message
from sre_platform.settings import Settings


REQ_COUNT = Counter("http_requests_total", "HTTP requests", ["path", "method", "status"])
REQ_LAT = Histogram("http_request_latency_seconds", "Latency", ["path", "method"])


def create_app() -> Flask:
    settings = Settings()
    setup_logging("api")
    log = logger(__name__, "api")

    app = Flask(__name__)

    async def _get_queue() -> RedisQueue:
        import redis.asyncio as redis  # local import for cold start

        client = redis.Redis(
            host=settings.redis_host,
            port=settings.redis_port,
            password=settings.redis_auth_token or None,
            socket_timeout=5,
            socket_connect_timeout=5,
            retry_on_timeout=True,
            health_check_interval=30,
        )
        return RedisQueue(client)

    @app.get("/healthz")
    def healthz():
        return jsonify({"ok": True, "env": settings.app_env})

    @app.get("/metrics")
    def metrics():
        return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}

    @app.post("/ingest")
    def ingest():
        with REQ_LAT.labels("/ingest", "POST").time():
            payload = request.get_json(force=True, silent=False) or {}
            msg = make_message("event", payload)
            asyncio.run(_get_queue().push(QueueNames.events, msg))
            REQ_COUNT.labels("/ingest", "POST", "202").inc()
            log.info("enqueued_event", extra={"event_id": msg["id"]})
            return jsonify({"queued": True, "id": msg["id"]}), 202

    return app

