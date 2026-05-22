from __future__ import annotations

import logging
import os
from pythonjsonlogger.json import JsonFormatter


def setup_logging(service_name: str) -> None:
    level = os.getenv("LOG_LEVEL", "INFO").upper()

    handler = logging.StreamHandler()
    handler.setFormatter(
        JsonFormatter(
            "%(asctime)s %(levelname)s %(name)s %(message)s %(service)s %(trace_id)s"
        )
    )

    root = logging.getLogger()
    root.handlers = []
    root.addHandler(handler)
    root.setLevel(level)

    logging.LoggerAdapter(logging.getLogger(__name__), {"service": service_name})


def logger(name: str, service: str) -> logging.LoggerAdapter:
    base = logging.getLogger(name)
    return logging.LoggerAdapter(base, {"service": service, "trace_id": os.getenv("TRACE_ID", "")})

