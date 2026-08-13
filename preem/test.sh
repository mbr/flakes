#!/bin/sh
set -eu

cd "$(dirname "$0")"

cargo test --manifest-path backend/Cargo.toml
