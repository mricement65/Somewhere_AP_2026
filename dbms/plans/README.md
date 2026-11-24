# PostgreSQL query plans

This folder contains raw `EXPLAIN (ANALYZE, BUFFERS)` captures for the
queries labeled Q01-Q12 in [`04_queries.sql`](../04_queries.sql). The runs
correspond to the benchmark cases and timings in
[`05_query_timings.md`](../05_query_timings.md).

## Files

- `Q01a` and `Q01b`: account insert/upsert.
- `Q02` and `Q03`: primary-key user reads and position updates.
- `Q04` and `Q05`: world loading and seeding.
- `Q06` and `Q07`: block insert and delete.
- `Q08`-`Q12`: session lookup, insert/upsert, update, delete, and cleanup.
- Each filename ends in `run1.txt`, `run2.txt`, or `run3.txt` to identify
  the sample matching the timing table.

These are coursework execution-plan records for the synthetic fixture
described in `05_query_timings.md`, not application configuration.
