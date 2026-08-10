#!/bin/sh
set -eu

cd "$(dirname "$0")"

case "${1:-}" in
  --check)
    cargo fmt --manifest-path backend/Cargo.toml -- \
      --config group_imports=StdExternalCrate \
      --config imports_granularity=Crate \
      --check
    elm-format --validate frontend/src
    nixfmt --check \
      flake.nix \
      nixos-module.nix \
      backend/package.nix \
      frontend/elm-srcs.nix \
      frontend/package.nix
    ;;
  "")
    cargo fmt --manifest-path backend/Cargo.toml -- \
      --config group_imports=StdExternalCrate \
      --config imports_granularity=Crate
    elm-format --yes frontend/src
    nixfmt \
      flake.nix \
      nixos-module.nix \
      backend/package.nix \
      frontend/elm-srcs.nix \
      frontend/package.nix
    ;;
  *)
    echo "usage: ./format.sh [--check]" >&2
    exit 2
    ;;
esac
