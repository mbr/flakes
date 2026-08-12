#!/bin/sh
set -eu

cd "$(dirname "$0")"

case "${1:-}" in
  --check)
    nixfmt --check flake.nix nixos-module.nix
    ./backend/format.sh --check
    ./frontend/format.sh --check
    ;;
  "")
    nixfmt flake.nix nixos-module.nix
    ./backend/format.sh
    ./frontend/format.sh
    ;;
  *)
    echo "usage: ./format.sh [--check]" >&2
    exit 2
    ;;
esac
