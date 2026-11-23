# Query timings · Somewhere

PostgreSQL 17.12, x86-64 Linux, local standalone backend, one client. Each value is the server’s **Execution Time** from `EXPLAIN (ANALYZE, BUFFERS)` in milliseconds. Planning, connection setup, network latency, and commit latency are excluded. Results describe the synthetic fixture below. Three samples are enough to document these runs but too few to infer production throughput.

| Query | Operation | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Raw plans |
|---|---|---:|---:|---:|---:|---|
| Q01a | New account | 1.356 | 0.066 | 0.028 | 0.483 | [1](plans/Q01a_run1.txt) · [2](plans/Q01a_run2.txt) · [3](plans/Q01a_run3.txt) |
| Q01b | Returning account | 1.191 | 0.050 | 0.117 | 0.453 | [1](plans/Q01b_run1.txt) · [2](plans/Q01b_run2.txt) · [3](plans/Q01b_run3.txt) |
| Q02 | Load user | 0.057 | 0.016 | 0.019 | 0.031 | [1](plans/Q02_run1.txt) · [2](plans/Q02_run2.txt) · [3](plans/Q02_run3.txt) |
| Q03 | Save position | 1.036 | 0.203 | 0.036 | 0.425 | [1](plans/Q03_run1.txt) · [2](plans/Q03_run2.txt) · [3](plans/Q03_run3.txt) |
| Q04 | Load world | 0.131 | 0.045 | 0.041 | 0.072 | [1](plans/Q04_run1.txt) · [2](plans/Q04_run2.txt) · [3](plans/Q04_run3.txt) |
| Q05 | Seed empty world | 2.322 | 1.805 | 1.704 | 1.944 | [1](plans/Q05_run1.txt) · [2](plans/Q05_run2.txt) · [3](plans/Q05_run3.txt) |
| Q06 | Place in empty cell | 0.186 | 0.047 | 0.052 | 0.095 | [1](plans/Q06_run1.txt) · [2](plans/Q06_run2.txt) · [3](plans/Q06_run3.txt) |
| Q07 | Remove occupied cell | 0.082 | 0.032 | 0.026 | 0.047 | [1](plans/Q07_run1.txt) · [2](plans/Q07_run2.txt) · [3](plans/Q07_run3.txt) |
| Q08 | Get live session and profile | 0.363 | 0.028 | 0.019 | 0.137 | [1](plans/Q08_run1.txt) · [2](plans/Q08_run2.txt) · [3](plans/Q08_run3.txt) |
| Q09a | New session | 0.691 | 0.082 | 0.083 | 0.285 | [1](plans/Q09a_run1.txt) · [2](plans/Q09a_run2.txt) · [3](plans/Q09a_run3.txt) |
| Q09b | Update session | 0.283 | 0.066 | 0.045 | 0.131 | [1](plans/Q09b_run1.txt) · [2](plans/Q09b_run2.txt) · [3](plans/Q09b_run3.txt) |
| Q10 | Touch live session | 0.238 | 0.053 | 0.043 | 0.111 | [1](plans/Q10_run1.txt) · [2](plans/Q10_run2.txt) · [3](plans/Q10_run3.txt) |
| Q11 | Destroy session | 0.132 | 0.020 | 0.017 | 0.056 | [1](plans/Q11_run1.txt) · [2](plans/Q11_run2.txt) · [3](plans/Q11_run3.txt) |
| Q12 | Purge 100 expired sessions | 0.100 | 0.064 | 0.059 | 0.074 | [1](plans/Q12_run1.txt) · [2](plans/Q12_run2.txt) · [3](plans/Q12_run3.txt) |

## Reproduce the fixture

Use a disposable empty database. In one psql session run `\i 03_schema.sql`, then `\i 04_queries.sql`, followed by the SQL below. Identity values start at 1. The fixture contains 1,000 accounts, 1,000 sessions (100 expired), and 427 blocks in the repository’s seed layout.

```sql
INSERT INTO app_user (google_id, display_name)
SELECT 'g-' || n, 'Player ' || n FROM generate_series(1,1000) n;
INSERT INTO web_session (session_id, user_id, expires_at)
SELECT 's-' || n, n, CASE WHEN n <= 100 THEN '2000-01-01'::timestamptz
                         ELSE '2100-01-01'::timestamptz END FROM generate_series(1,1000) n;
EXECUTE world_seed;
ANALYZE app_user;
ANALYZE web_session;
ANALYZE world_block;
```

## Repeat the measurements

Each query case used a fresh standalone backend against the same fixture. Three runs of the same case shared that backend and its cache. For each run issue `BEGIN;`, then `EXPLAIN (ANALYZE, BUFFERS) EXECUTE ...;`, then `ROLLBACK;`. For Q05 only, issue `TRUNCATE world_block;` just after BEGIN so the seed starts with zero blocks. The truncate is outside the timed statement. Rollback restores logical rows between runs. Sequence increments can persist. The benchmark does not flush OS caches or promise cold-cache results. Each linked text file contains the complete plan rows emitted by PostgreSQL.

| Case | Statement to put after EXPLAIN (ANALYZE, BUFFERS) |
|---|---|
| Q01a | `EXECUTE user_login('new-google','New Player');` |
| Q01b | `EXECUTE user_login('g-500','Updated Player');` |
| Q02 | `EXECUTE user_by_id(500);` |
| Q03 | `EXECUTE position_save(500,3,2.5,-4);` |
| Q04 | `EXECUTE world_load;` |
| Q05 | `EXECUTE world_seed;` |
| Q06 | `EXECUTE block_place(12,1,12,'sand');` |
| Q07 | `EXECUTE block_remove(0,0,0);` |
| Q08 | `EXECUTE session_get('s-500');` |
| Q09a | `EXECUTE session_set('s-new',500,'2100-02-01','{}');` |
| Q09b | `EXECUTE session_set('s-500',500,'2100-02-01','{}');` |
| Q10 | `EXECUTE session_touch('s-500','2100-02-01');` |
| Q11 | `EXECUTE session_destroy('s-500');` |
| Q12 | `EXECUTE sessions_expire;` |
