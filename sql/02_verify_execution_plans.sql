-- Execution-plan verification only.
-- These queries do not modify benchmark tables.

EXPLAIN (ANALYZE, BUFFERS)
SELECT score FROM benchmark_10000_noindex WHERE lookup_key = 50007;

EXPLAIN (ANALYZE, BUFFERS)
SELECT score FROM benchmark_10000_bplus WHERE lookup_key = 50007;

EXPLAIN (ANALYZE, BUFFERS)
SELECT score FROM benchmark_10000_hash WHERE lookup_key = 50007;

EXPLAIN (ANALYZE, BUFFERS)
SELECT score FROM benchmark_100000_noindex WHERE lookup_key = 50007;

EXPLAIN (ANALYZE, BUFFERS)
SELECT score FROM benchmark_100000_bplus WHERE lookup_key = 50007;

EXPLAIN (ANALYZE, BUFFERS)
SELECT score FROM benchmark_100000_hash WHERE lookup_key = 50007;

EXPLAIN (ANALYZE, BUFFERS)
SELECT score FROM benchmark_500000_noindex WHERE lookup_key = 50007;

EXPLAIN (ANALYZE, BUFFERS)
SELECT score FROM benchmark_500000_bplus WHERE lookup_key = 50007;

EXPLAIN (ANALYZE, BUFFERS)
SELECT score FROM benchmark_500000_hash WHERE lookup_key = 50007;
