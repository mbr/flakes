#!/bin/sh

#: Produces flame graphs for a profiling binary on every generated workload.

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <binary-name>" >&2
    exit 2
fi

binary_name=$1
data_dir=${BENCHMARK_DATA_DIR:-bench-data}
results_root=${PERF_RESULTS_DIR:-perf-results}
runs=${PERF_RUNS:-50}
frequency=${PERF_FREQUENCY:-997}
event=${PERF_EVENT:-cycles:u}
allowed_cpus=${BENCHMARK_CPUS:-0}
memory_max=${BENCHMARK_MEMORY_MAX:-200M}
features=${BENCHMARK_CARGO_FEATURES:-}

if [ "$(uname -s)" != Linux ]; then
    echo "perf profiling is supported only on Linux" >&2
    exit 1
fi

for command in perf stackcollapse-perf.pl flamegraph.pl systemd-run; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "required command not found: $command" >&2
        exit 1
    fi
done

case $runs in
    '' | *[!0-9]*)
        echo "PERF_RUNS must be a positive integer" >&2
        exit 2
        ;;
esac
if [ "$runs" -eq 0 ]; then
    echo "PERF_RUNS must be a positive integer" >&2
    exit 2
fi

set -- "$data_dir"/*.txt
if [ ! -e "$1" ]; then
    echo "no benchmark inputs found; run the data generator first" >&2
    exit 1
fi

hostname=$(hostname)
safe_hostname=$(printf '%s' "$hostname" | LC_ALL=C tr -c 'A-Za-z0-9._-' '_')
timestamp=$(date -u +%Y-%m-%dT%H-%M-%SZ)
results_dir=$results_root/$safe_hostname/$timestamp-$binary_name

if [ -e "$results_dir" ]; then
    results_dir=$results_dir-$$
fi

if [ -n "$(git status --porcelain --untracked-files=normal 2>/dev/null || true)" ]; then
    git_dirty=true
else
    git_dirty=false
fi

git_commit=$(git rev-parse HEAD 2>/dev/null || printf unknown)
mkdir -p "$results_dir"
temporary_dir=$(mktemp -d)
trap 'rm -rf "$temporary_dir"' EXIT HUP INT TERM

{
    printf 'hostname=%s\n' "$hostname"
    printf 'timestamp=%s\n' "$timestamp"
    printf 'binary=%s\n' "$binary_name"
    printf 'git_commit=%s\n' "$git_commit"
    printf 'git_dirty=%s\n' "$git_dirty"
    printf 'runs=%s\n' "$runs"
    printf 'frequency=%s\n' "$frequency"
    printf 'event=%s\n' "$event"
    printf 'allowed_cpus=%s\n' "$allowed_cpus"
    printf 'memory_max=%s\n' "$memory_max"
    printf 'cargo_features=%s\n' "$features"
    printf 'system=%s\n' "$(uname -a)"
    printf 'rustc=%s\n' "$(rustc --version)"
    printf 'perf=%s\n' "$(perf version)"
} > "$results_dir/metadata.txt"

if [ -n "$features" ]; then
    cargo build --profile profiling --features "$features" --bin "$binary_name"
else
    cargo build --profile profiling --bin "$binary_name"
fi
binary=target/profiling/$binary_name

for input in "$data_dir"/*.txt; do
    workload=${input##*/}
    workload=${workload%.txt}
    perf_data=$temporary_dir/$workload.data
    stacks=$temporary_dir/$workload.stacks
    folded=$temporary_dir/$workload.folded
    flame_graph=$results_dir/$workload.svg

    echo "profiling $binary_name with $input"
    systemd-run --user --quiet --scope \
        -p "AllowedCPUs=$allowed_cpus" \
        -p "MemoryMax=$memory_max" \
        -p MemorySwapMax=0 \
        perf record \
            --quiet \
            --event "$event" \
            --freq "$frequency" \
            --call-graph dwarf,16384 \
            --output "$perf_data" \
            -- \
            sh -c '
                run=0
                while [ "$run" -lt "$1" ]; do
                    "$2" < "$3" >/dev/null
                    run=$((run + 1))
                done
            ' profile "$runs" "$binary" "$input"

    perf script --input "$perf_data" > "$stacks"
    stackcollapse-perf.pl "$stacks" > "$folded"
    flamegraph.pl --title "$binary_name: $workload" "$folded" > "$flame_graph"
done

printf 'flame graphs written to %s\n' "$results_dir"
