#!/usr/bin/env bash
# sina.sh N... : on the target, select each contestant, start it on a fresh database and run the 28 API checks.
for N in "$@"; do
  echo "=== $N"
  /srv/bench/sec.sh "$N" && /srv/bench/fresh.sh >/tmp/fresh-$N.log 2>&1 || { echo "BOOT FAIL"; tail -15 /tmp/fresh-$N.log; continue; }
  python3 /srv/bench/test_api.py http://127.0.0.1:80 /srv/seed/tokens.json | grep -E "FAIL|passed=" 
  systemctl show yarisma -p MemoryCurrent | sed 's/MemoryCurrent=/memory bytes: /'
  systemctl stop yarisma
done
