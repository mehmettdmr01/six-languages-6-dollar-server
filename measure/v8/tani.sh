#!/usr/bin/env bash
# tani.sh NAME USERS : run on generator 1 after the queue. Starts NAME on a fresh database, sends USERS (half per
# generator, 60 s ramp, 90 s hold) and samples the app every 3 s: RSS, open notes.db descriptors, OS threads.
set -u
N="$1"; U="$2"; P=10.110.0.4; H=$((U / 2))
ssh root@$P "/srv/bench/sec.sh $N && /srv/bench/fresh.sh >/dev/null"
ssh root@$P "nohup bash -c 'for i in \$(seq 60); do pid=\$(systemctl show -p MainPID --value yarisma); echo \"\$(date +%s) rss_mb=\$(( \$(ps -o rss= -p \$pid 2>/dev/null || echo 0) / 1024 )) db_fds=\$(ls -l /proc/\$pid/fd 2>/dev/null | grep -c notes.db) all_fds=\$(ls /proc/\$pid/fd 2>/dev/null | wc -l) threads=\$(ls /proc/\$pid/task 2>/dev/null | wc -l) avail_mb=\$(awk \"/MemAvailable/{print int(\\\$2/1024)}\" /proc/meminfo)\"; sleep 3; done' > /tmp/tani-$N.log 2>&1 &"
ulimit -n 500000
k6 run -q -e BASE_URL=http://$P -e VUS=$H -e RAMP=60s -e HOLD=90s -e TOKENS=/srv/olcum/seed/tokens.json /srv/olcum/yuk.js > /tmp/tani-k6-$N.log 2>&1 &
ssh root@10.110.0.3 "ulimit -n 500000; k6 run -q -e BASE_URL=http://$P -e VUS=$H -e RAMP=60s -e HOLD=90s -e TOKENS=/srv/olcum/seed/tokens.json /srv/olcum/yuk.js > /tmp/tani-k6-$N.log 2>&1"
wait
sleep 5
ssh root@$P "cat /tmp/tani-$N.log; systemctl is-active yarisma; journalctl -k --since '-4 min' --no-pager | grep -iE 'oom|killed process' | tail -2; systemctl stop yarisma"
