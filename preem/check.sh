#!/bin/sh
set -eu

cd "$(dirname "$0")"

./format.sh --check
cargo test --manifest-path backend/Cargo.toml
cargo clippy --manifest-path backend/Cargo.toml --all-targets -- -D warnings
./frontend/build.sh
