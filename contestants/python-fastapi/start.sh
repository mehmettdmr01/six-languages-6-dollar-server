#!/usr/bin/env bash
cd "$(dirname "$0")"; exec .venv/bin/fastapi run main.py --host "$HOST" --port "$PORT"
