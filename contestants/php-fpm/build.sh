#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
{ php -v | head -1; nginx -v 2>&1; } > versions.txt
