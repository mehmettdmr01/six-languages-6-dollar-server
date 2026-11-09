# Which language can handle the most users on a $6 server?

Video: (link coming)

The same small notes API in six languages, each run **the way its framework's own docs run it, with no tuning**, on the
same DigitalOcean **$6/month server (1 vCPU, 1 GB RAM)**. Simulated users (each clicks every 5-15 seconds) ramp up over
5 minutes until it breaks; then 5-minute holds just below the break. **Score = the most users held for 5 minutes with
p95 under 1 s and under 1% errors** (and the process still alive). All six were measured on the same server in one
session; Express was also measured the day before on that server and scored exactly the same.

## Results (9 Nov 2026)

| | Contestant | Score | Broke at | How it broke | p95 at the score | req/s | Memory at the score | Memory idle |
|---|---|---|---|---|---|---|---|---|
| 1 | Rust / Axum + sqlx | **17,600** | 21,666 | out of memory: Axum keeps every connection open (17,605 open at 17,600 users, ~23 KB each); the 1 GB filled at ~29,000 connections | 566 ms | 1,562 | 579 MB | 6 MB |
| 2 | Node / Express | **15,800** (day 1: 15,800) | 17,500 | errors; `Possible SYN flooding`: 5 s keep-alive, users reconnect on every click | 476 ms | 1,388 | 471 MB | 83 MB |
| 3 | Go / net/http + database/sql + mattn/go-sqlite3 | **12,200** | 15,000 | out of memory: the `database/sql` pool has no limit by default; with writes queued behind SQLite's single writer it opened ~1,000 SQLite connections (open `notes.db` descriptors 7-9 → 3,176, OS threads 4 → 470) | 206 ms | 1,083 | 697 MB | 9 MB |
| 4 | Java / Spring Boot (Tomcat) + JdbcTemplate + sqlite-jdbc | **6,800** | 7,500 | errors; `Possible SYN flooding`: Tomcat's default `max-connections` 8,192 (at 11,000 users open descriptors stayed flat at 8,225, memory flat at 405 MB, CPU a third idle) | **15 ms** | 607 | 553 MB | 186 MB |
| 5 | PHP 8.3 + PHP-FPM + nginx (Ubuntu defaults) | **5,400** | 6,666 | errors: nginx `worker_connections 768` with one worker on one core (open connections never past ~900); FPM `pm.max_children = 5` | 283 ms | 481 | 114 MB | 24 MB |
| 6 | Python / FastAPI (`fastapi run`, 1 worker) + sqlite3 | **2,000** | 3,333 | latency over 1 s with 0 errors; CPU 87% busy at 2,200 users | 878 ms | 176 | 137 MB | 77 MB |

- All six passed the 28 API checks and the hidden test (no caching; a token changed in the database takes effect at once;
  the server is `kill -9`ed while writers run and every note that got a 201 must be in the database).
- Rust is ahead of Express by 11%, about one step of the search (holds go down in ~10% steps).
- **Four of six were brought down by a default setting**, not by the speed of the language: nginx's 768, Tomcat's 8,192,
  Go's unlimited pool, Axum's connections that never close. Python was the only one that simply ran out of CPU.
- The Go and Java mechanisms come from a separate diagnostic run after the queue ([measure/v8/tani.sh](measure/v8/tani.sh),
  [results/diagnostics](results/diagnostics)): the app under a fixed load, sampled every 3 s (RSS, open `notes.db`
  descriptors, all descriptors, threads, free memory).
- Go and Java listen on a dual-stack IPv6 socket, so the `tcp_inuse` column of the per-second box CSVs (IPv4 only) reads 4-6
  for them; their connection counts come from the diagnostic.

## "No tuning" per contestant

Each folder's `README.md` says exactly how it runs. In short: Express with Node's defaults; FastAPI with `fastapi run`
(one worker) and a connection per request through `Depends` (the docs' pattern); Go's standard library server and
`database/sql` defaults; Axum on Tokio with sqlx's default pool; Spring Boot `java -jar` with the default heap and Hikari
pool; PHP through Ubuntu's own `nginx.conf` and FPM `www.conf`, only file paths changed so they run as the benchmark user.
The POST handlers in FastAPI and Spring read the raw body because the API wants the token checked before the JSON is parsed.
Exact versions: `contestants/*/versions.txt` and the lock files.

## Files

| Path | What it is |
|---|---|
| `contestants/<name>/` | the six apps: `install.sh` (packages), `build.sh` (built on the load generator), `start.sh` (what systemd runs), source, lock files, `versions.txt` |
| `load-test/yuk.js` | the k6 user model; `prob.py` is a one-request-per-second latency probe |
| `measure/SPEC.md` | the API every contestant implements |
| `measure/seed.py` | the deterministic database: 20,000 users, 1,000,000 notes |
| `measure/test_api.py`, `measure/gizli_test.py` | the 28 API checks and the hidden test |
| `measure/arama.py` | ramp, find the break, 5-minute holds; writes `kosular.json` and `sonuc.json` |
| `measure/dagit.sh`, `measure/uzak/`, `measure/do_kutu.py` | set up the rented boxes, the per-second sampler (`izle.py`), create/delete droplets |
| `measure/v8/` | this video's queue (`sira8.sh`), the diagnostic (`tani.sh`), the pre-test and the waiter |
| `results/day-2-all-six/<name>/` | every ramp and hold: `kosular.json`, per-second box CSVs, probe CSVs, test output |
| `results/day-1-express/`, `results/diagnostics/`, `results/box-day-*.txt` | the day-1 Express run, the Go/Java diagnostics, the server's CPU and disk numbers |

Some names are Turkish (yük = load, arama = search, gizli = hidden, sonuç = result, kutu = box, tanı = diagnosis).

## Limits

One app, a mostly-read load (70% list, 20% one note, 10% write) on SQLite, one server type, every language at its
defaults, one round. With tuning the ranking will change; that is the next video. Server cost: about $0.75.

The setup follows Arjay McCandless's $12 server videos (e.g.
[Which Programming Language Can Handle the Most Users on a $12 Server?](https://youtu.be/sQXFhh_PiG4)); the test, the
user model and the score are my own, so the numbers are not comparable with his.

I make this channel with Claude Code's help, and the narration is a synthesized voice. The measurements are real; every
file is here to check.
