# Problem benchmark workspace

This template provides a repeatable workflow for optimizing stdin-to-stdout coding problems. It starts with a small sample problem that sums unsigned integers; replace the sample implementations and workloads with the target problem.

## Project setup

Update the package metadata in `Cargo.toml`, then adapt:

- `src/bin/baseline.rs`: straightforward reference implementation.
- `src/bin/wip.rs`: candidate implementation under optimization.
- `src/bin/generate-test-data.rs`: deterministic representative workload generator.
- `expected-results.txt`: trusted output for each generated workload.

Additional candidate binaries can live under `src/bin/` and use the same harness.

Generate the sample workloads with:

```sh
cargo run --release --bin generate-test-data
```

Generated inputs are written to the ignored `bench-data/` directory.

## Correctness

Build and verify a candidate against every generated workload:

```sh
cargo build --release --bin wip
./test.sh target/release/wip
```

`test.sh` compares the candidate's complete standard output with the value named for each `bench-data/*.txt` file in `expected-results.txt`. `BENCHMARK_DATA_DIR` and `EXPECTED_RESULTS_FILE` override those paths.

Run the candidate against one representative input while iterating:

```sh
./run.sh
./run.sh baseline bench-data/small.txt
```

## Benchmarking

Benchmark a release binary against every generated workload:

```sh
./bench.sh wip
```

Each run writes Hyperfine JSON and environment metadata beneath a timestamped `bench-results/<hostname>/` directory. Results remain trackable so important measurements can be committed. Metadata records the source revision, dirty state, tool versions, and benchmark parameters.

On Linux, `bench.sh` automatically uses a transient user systemd scope for CPU and memory limits when `systemd-run` is available. Set `BENCHMARK_RESOURCE_LIMITS=false` to disable this or `true` to require it.

The following environment variables configure benchmark runs:

- `BENCHMARK_RUNS` and `BENCHMARK_WARMUP` control Hyperfine repetitions.
- `BENCHMARK_LABEL` records an experiment label.
- `BENCHMARK_CARGO_FEATURES` enables a comma-separated Cargo feature list.
- `BENCHMARK_DATA_DIR` and `BENCHMARK_RESULTS_DIR` override storage paths.
- `BENCHMARK_CPUS` and `BENCHMARK_MEMORY_MAX` control resource limits.

Summarize all recorded runs or one results directory with:

```sh
./summarize-benchmarks.sh
./summarize-benchmarks.sh bench-results/example-host
```

The summary discovers workload names from the recorded JSON and reports per-workload median runtime, aggregate runtime, and peak memory.

## Profiling

Produce a flame graph for every generated workload on Linux:

```sh
./perf.sh wip
```

The script builds the optimized `profiling` Cargo profile with debug information. It uses `cargo-flamegraph` to aggregate samples from repeated executions of short-lived binaries and writes SVGs plus metadata beneath the ignored `perf-results/<hostname>/` directory.

`PERF_RUNS`, `PERF_FREQUENCY`, and `PERF_RESULTS_DIR` configure profiling. Profiling also honors `BENCHMARK_CARGO_FEATURES`, `BENCHMARK_DATA_DIR`, `BENCHMARK_CPUS`, and `BENCHMARK_MEMORY_MAX`.
