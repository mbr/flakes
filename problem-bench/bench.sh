#!/bin/sh

#: Benchmarks a release binary against every generated workload.

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <binary-name>" >&2
    exit 2
fi

binary_name=$1
data_dir=${BENCHMARK_DATA_DIR:-bench-data}
results_root=${BENCHMARK_RESULTS_DIR:-bench-results}
runs=${BENCHMARK_RUNS:-3}
warmups=${BENCHMARK_WARMUP:-1}
allowed_cpus=${BENCHMARK_CPUS:-0}
memory_max=${BENCHMARK_MEMORY_MAX:-200M}
resource_limits=${BENCHMARK_RESOURCE_LIMITS:-auto}
features=${BENCHMARK_CARGO_FEATURES:-}
label=${BENCHMARK_LABEL:-}

case $resource_limits in
    auto)
        if [ "$(uname -s)" = Linux ] && command -v systemd-run >/dev/null 2>&1; then
            resource_limits=true
        else
            resource_limits=false
        fi
        ;;
    true | false) ;;
    *)
        echo "BENCHMARK_RESOURCE_LIMITS must be auto, true, or false" >&2
        exit 2
        ;;
esac

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

{
    printf 'hostname=%s\n' "$hostname"
    printf 'timestamp=%s\n' "$timestamp"
    printf 'binary=%s\n' "$binary_name"
    printf 'label=%s\n' "$label"
    printf 'git_commit=%s\n' "$git_commit"
    printf 'git_dirty=%s\n' "$git_dirty"
    printf 'runs=%s\n' "$runs"
    printf 'warmups=%s\n' "$warmups"
    printf 'resource_limits=%s\n' "$resource_limits"
    printf 'allowed_cpus=%s\n' "$allowed_cpus"
    printf 'memory_max=%s\n' "$memory_max"
    printf 'cargo_features=%s\n' "$features"
    printf 'system=%s\n' "$(uname -a)"
    printf 'rustc=%s\n' "$(rustc --version)"
    printf 'hyperfine=%s\n' "$(hyperfine --version)"
} > "$results_dir/metadata.txt"

if [ -n "$features" ]; then
    cargo build --release --features "$features" --bin "$binary_name"
else
    cargo build --release --bin "$binary_name"
fi

for input in "$data_dir"/*.txt; do
    workload=${input##*/}
    workload=${workload%.txt}

    echo "benchmarking $binary_name with $input"
    if [ "$resource_limits" = true ]; then
        systemd-run --user --quiet --scope \
            -p "AllowedCPUs=$allowed_cpus" \
            -p "MemoryMax=$memory_max" \
            -p MemorySwapMax=0 \
            hyperfine \
                --export-json "$results_dir/$workload.json" \
                --input "$input" \
                --runs "$runs" \
                --shell=none \
                --warmup "$warmups" \
                "target/release/$binary_name"
    else
        hyperfine \
            --export-json "$results_dir/$workload.json" \
            --input "$input" \
            --runs "$runs" \
            --shell=none \
            --warmup "$warmups" \
            "target/release/$binary_name"
    fi
done

printf 'results written to %s\n' "$results_dir"
