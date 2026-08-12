#!/bin/sh
set -eu

cd "$(dirname "$0")"

cargo build --manifest-path backend/Cargo.toml "$@"
./frontend/build.sh "$@"
