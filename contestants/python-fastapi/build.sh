#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python3 -m venv .venv
# requirements.lock is the pip freeze of the first build (8 Nov 2026), so later builds get the same versions
if [ -f requirements.lock ]; then .venv/bin/pip install -q -r requirements.lock; else .venv/bin/pip install -q "fastapi[standard]"; fi
{ python3 --version; .venv/bin/pip freeze | grep -iE '^(fastapi|uvicorn|starlette|pydantic)=='; } > versions.txt
