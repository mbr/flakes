#!/bin/sh
set -eu

cd "$(dirname "$0")"

case "${1:-}" in
  --check | "") ;;
  *) echo "usage: ./format.sh [--check]" >&2; exit 2 ;;
esac

nixfmt "$@" flake.nix nixos-module.nix
./backend/format.sh "$@"
./frontend/format.sh "$@"
