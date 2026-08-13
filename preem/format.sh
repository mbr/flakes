#!/bin/sh

#: Formats all project sources and Nix expressions.

set -eu

cd "$(dirname "$0")"

nixfmt "$@" flake.nix nixos-module.nix
./backend/format.sh "$@"
./frontend/format.sh "$@"
