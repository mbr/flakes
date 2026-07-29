#!/bin/sh

#: Verifies a binary against every generated workload.

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <binary-path>" >&2
    exit 2
fi

binary=$1
data_dir=${BENCHMARK_DATA_DIR:-bench-data}
expected_file=${EXPECTED_RESULTS_FILE:-expected-results.txt}

if [ ! -x "$binary" ]; then
    echo "binary is not executable: $binary" >&2
    exit 1
fi

if [ ! -f "$expected_file" ]; then
    echo "expected results file does not exist: $expected_file" >&2
    exit 1
fi

set -- "$data_dir"/*.txt
if [ ! -e "$1" ]; then
    echo "no test inputs found; run the data generator first" >&2
    exit 1
fi

count=0
for input in "$data_dir"/*.txt; do
    workload=${input##*/}
    workload=${workload%.txt}

    if ! expected=$(awk -F= -v workload="$workload" '
        $1 == workload {
            print substr($0, index($0, "=") + 1)
            found = 1
            exit
        }
        END {
            if (!found) exit 1
        }
    ' "$expected_file"); then
        echo "no expected result recorded for $workload" >&2
        exit 1
    fi

    echo "testing $workload"
    if ! actual=$("$binary" < "$input"); then
        echo "binary failed for $workload" >&2
        exit 1
    fi

    if [ "$actual" != "$expected" ]; then
        echo "incorrect result for $workload: expected '$expected', got '$actual'" >&2
        exit 1
    fi

    count=$((count + 1))
done

printf 'all %s workloads passed\n' "$count"
