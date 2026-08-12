#!/bin/sh
set -eu

cd "$(dirname "$0")"

case "${1:-}" in
  --check)
    elm-format --validate src
    nixfmt --check elm-srcs.nix package.nix
    ;;
  "")
    elm-format --yes src
    nixfmt elm-srcs.nix package.nix
    ;;
  *)
    echo "usage: ./format.sh [--check]" >&2
    exit 2
    ;;
esac
