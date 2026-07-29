#!/bin/sh

#: Runs a candidate solution against a representative workload.

set -eu

if [ "$#" -gt 2 ]; then
    echo "usage: $0 [binary-name] [input-file]" >&2
    exit 2
fi

binary_name=${1:-wip}
input=${2:-bench-data/large.txt}

if [ ! -f "$input" ]; then
    echo "input does not exist: $input" >&2
    echo "run the data generator first" >&2
    exit 1
fi

time cargo run --release --quiet --bin "$binary_name" < "$input"
