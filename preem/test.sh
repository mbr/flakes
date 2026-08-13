#!/bin/sh

#: Runs the project test suite.

set -eu

cd "$(dirname "$0")"

cargo test --manifest-path backend/Cargo.toml
