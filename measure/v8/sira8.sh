#!/usr/bin/env bash
# The V8 queue, run in tmux on the first generator. One round, 5-minute ramps, two generators (cap 50,000).
cd /srv/olcum
for N in node-express-tutorial python-fastapi php-fpm go-nethttp rust-axum java-spring; do
  echo "=== $N $(date -u +%H:%M)" >> sira8.log
  python3 arama.py --target root@10.110.0.4 --target-ip 10.110.0.4 --gen local --gen root@10.110.0.3 --name "$N" --tier v8 --out sonuc \
    --first 25000 --cap 50000 --ramp-seconds 300 >> "kos8-$N.log" 2>&1
  echo "$N exit $? $(date -u +%H:%M)" >> sira8.log
done
echo "BITTI $(date -u +%H:%M)" >> sira8.log
