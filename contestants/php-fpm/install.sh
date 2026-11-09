#!/usr/bin/env bash
set -euo pipefail
apt-get -o DPkg::Lock::Timeout=300 update -q; apt-get -o DPkg::Lock::Timeout=300 install -y -q nginx php8.3-fpm php8.3-sqlite3 php8.3-mbstring
# The packages start their own services on install; the benchmark runs them from start.sh instead.
systemctl disable --now nginx php8.3-fpm 2>/dev/null || true
