#!/bin/sh
set -eu

cd "$(dirname "$0")"

case "${1:-all}" in
  all)
    cargo build --manifest-path backend/Cargo.toml
    ./frontend/build.sh
    ;;
  backend)
    cargo build --manifest-path backend/Cargo.toml
    ;;
  frontend)
    ./frontend/build.sh
    ;;
  *)
    echo "usage: ./build.sh [all|backend|frontend]" >&2
    exit 2
    ;;
esac
