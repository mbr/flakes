#!/bin/sh

#: Formats or validates the Elm sources.

set -eu

cd "$(dirname "$0")"

case "${1:-}" in
  --check) elm_format_flag=--validate ;;
  "") elm_format_flag=--yes ;;
  *) echo "usage: ./format.sh [--check]" >&2; exit 2 ;;
esac

elm-format "$elm_format_flag" src
nixfmt "$@" elm-srcs.nix package.nix
