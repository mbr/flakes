#!/bin/sh
set -eu

cd "$(dirname "$0")"

nixfmt --check flake.nix nixos-module.nix
./backend/check.sh
./frontend/check.sh
