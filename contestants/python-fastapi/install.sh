#!/usr/bin/env bash
set -euo pipefail
apt-get -o DPkg::Lock::Timeout=300 update -q; apt-get -o DPkg::Lock::Timeout=300 install -y -q --no-install-recommends python3 python3-venv
