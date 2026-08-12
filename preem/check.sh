#!/bin/sh
set -eu

cd "$(dirname "$0")"

./format.sh --check

printf 'rustc %s at %s, cargo %s at %s\n' \
  "$(rustc --version)" \
  "$(which rustc)" \
  "$(cargo --version)" \
  "$(which cargo)"

RUSTFLAGS="${RUSTFLAGS:+$RUSTFLAGS }-D warnings" \
  cargo test --manifest-path backend/Cargo.toml
RUSTFLAGS="${RUSTFLAGS:+$RUSTFLAGS }-D warnings" \
  cargo check --manifest-path backend/Cargo.toml
cargo clippy --manifest-path backend/Cargo.toml -- -D warnings

./frontend/build.sh
