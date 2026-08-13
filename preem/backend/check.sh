#!/bin/sh

#: Checks backend formatting and lints all targets.

set -eu

cd "$(dirname "$0")"

./format.sh --check
cargo clippy --all-targets -- -D warnings
