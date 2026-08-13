#!/bin/sh

#: Runs project formatting and build checks.

set -eu

cd "$(dirname "$0")"

nixfmt --check flake.nix nixos-module.nix nixos-test.nix
./backend/check.sh
./frontend/check.sh
