# Throttled vs OOMKilled

A small reproducible benchmark showing why a CPU limit and a memory limit fail in completely different ways in Kubernetes — one throttles your pod, the other kills it outright.

The same task (find duplicate order IDs in a 50,000-row CSV) is implemented three times, the way most of us actually arrive at a "good" solution: badly, then fast-but-wrong, then actually right.

| | Approach | Time | Peak RSS | What happens in a real pod |
|---|---|---|---|---|
| `v1_naive.rb` | nested loop, O(n²) | 19.81s (8K rows) | 26MB | CPU-bound — pod throttles, requests queue up |
| `v2_hash_full_records.rb` | hash lookup, but caches full rows | 0.65s (50K rows) | 90MB | Fast, but OOMKilled crossing a 75MB limit |
| `v3_stream_set.rb` | hash lookup, streams the file, caches only the id | 0.08s (50K rows) | 29MB | Fast *and* stays well under any reasonable limit |

Full write-up, with the "why," the code walkthrough, and how to tell the two failure modes apart in production:
- [dev.to: High CPU gets throttled. High Memory gets killed.](https://dev.to/huzaifa_saifuddin_370679c/high-cpu-gets-throttled-high-memory-gets-killed-5g37)

## What's here

- `generate_orders.rb` — generates the test CSV (configurable row count, ~5% intentional duplicate order_ids)
- `v1_naive.rb` — O(n²) nested loop comparing every row to every other row
- `v2_hash_full_records.rb` — O(n) hash lookup, but caches every full CSV row — the "fixed CPU, broke memory" version
- `v3_stream_set.rb` — O(n) hash lookup, streams the file line-by-line, caches only the id — fixes both

## Run it yourself

Requires Ruby (no gems beyond the standard library).

```bash
# generate a fresh 50,000-row test file
ruby generate_orders.rb 50000 orders_full.csv
head -n 8001 orders_full.csv > orders_slice_8000.csv   # v1 is O(n^2); a slice keeps it fast

# measure each version (real/user time + peak memory in one shot)
/usr/bin/time -l ruby v1_naive.rb orders_slice_8000.csv      # macOS; use -v on Linux
/usr/bin/time -l ruby v2_hash_full_records.rb orders_full.csv
/usr/bin/time -l ruby v3_stream_set.rb orders_full.csv
```

## Measured output

From an actual run on an M1 MacBook (8 cores), `/usr/bin/time -l`:

```text
$ /usr/bin/time -l ruby v1_naive.rb orders_slice_8000.csv
rows: 8000, duplicate hits: 387
19.81 real   19.62 user   0.16 sys
maximum resident set size: 26MB
```

```text
$ /usr/bin/time -l ruby v2_hash_full_records.rb orders_full.csv
unique rows cached: 47480, duplicate hits: 2520
0.65 real   0.48 user   0.06 sys
maximum resident set size: 90MB
```

```text
$ /usr/bin/time -l ruby v3_stream_set.rb orders_full.csv
unique ids tracked: 47480, duplicate hits: 2520
0.08 real   0.06 user   0.01 sys
maximum resident set size: 29MB
```

`v1` ran on an 8,000-row slice since it's O(n²) — at the full 50,000 rows it projects to roughly 13 minutes. `v2` and `v3` ran on the full 50,000-row (23MB) file.

## Why this happens

- **CPU limits** are enforced by the kernel's CFS quota. Go over it and the scheduler just hands your process fewer time slices — it keeps running, just slower.
- **Memory limits** are enforced by the OOM killer. Go over it and the kernel sends `SIGKILL` — instantly, with no graceful degradation. The process is gone and restarts from zero.

Same-looking YAML (`cpu: "1"`, `memory: "512Mi"`), opposite failure modes. The full post linked above walks through both mechanisms and how to tell which one you're hitting in production.
