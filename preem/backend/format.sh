#!/bin/sh
set -eu

cd "$(dirname "$0")"

case "${1:-}" in
  --check)
    cargo fmt -- \
      --config group_imports=StdExternalCrate \
      --config imports_granularity=Crate \
      --check
    nixfmt --check package.nix
    ;;
  "")
    cargo fmt -- \
      --config group_imports=StdExternalCrate \
      --config imports_granularity=Crate
    nixfmt package.nix
    ;;
  *)
    echo "usage: ./format.sh [--check]" >&2
    exit 2
    ;;
esac
