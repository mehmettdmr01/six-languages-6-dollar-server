#!/usr/bin/env bash
# bekle.sh N : wait until N contestants have finished on the generator, then print their results.
cd "$(dirname "$0")/../.."
K="-i .anahtar/v7 -o BatchMode=yes -o ConnectTimeout=15"
for i in $(seq 1 120); do
  n=$(ssh $K root@<public-ip> 'grep -c " exit " /srv/olcum/sira8.log; true' 2>/dev/null | tail -1)
  [ "${n:-0}" -ge "$1" ] && break; sleep 60
done
ssh $K root@<public-ip> 'cat /srv/olcum/sira8.log; for f in /srv/olcum/sonuc/v8/*/kosular.json; do python3 -c "
import json,sys; k=json.load(open(sys.argv[1])); n=sys.argv[1].split(\"/\")[-2]
for r in k: print(n, r[\"run\"], \"PASS\" if r[\"passed\"] else r[\"why\"], \"knee\", r.get(\"knee\"), {x: round(r[\"k6\"][x],3) for x in (\"p95\",\"err\",\"rps\")} if r[\"k6\"] else None, \"steal\", r[\"box\"][\"mean_steal\"], \"mem\", r[\"box\"][\"peak_app_mb\"], \"availMin\", r[\"box\"][\"min_mem_avail_mb\"], \"tcp\", r[\"box\"][\"peak_tcp\"], r[\"kernel\"][:2])
" $f; done; grep -h "ABORT\|did not boot\|FAILED" /srv/olcum/kos8-*.log; true'
