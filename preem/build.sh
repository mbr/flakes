#!/bin/sh

#: Builds the backend and frontend artifacts.

set -eu

cd "$(dirname "$0")"

cargo build --manifest-path backend/Cargo.toml "$@"
just --justfile frontend/justfile build "$@"
