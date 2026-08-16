#!/bin/sh

#: Regenerates the pinned Elm dependency set.

set -eu

cd "$(dirname "$0")"

elm2nix convert > elm-srcs.nix
elm2nix snapshot --write-to registry.dat
nix fmt elm-srcs.nix
