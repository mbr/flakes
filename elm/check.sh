#!/bin/sh
set -eu

cd "$(dirname "$0")"

elm-format --validate src
nixfmt --check flake.nix elm-srcs.nix
./build.sh
