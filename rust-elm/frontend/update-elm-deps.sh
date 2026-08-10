#!/bin/sh
set -eu

cd "$(dirname "$0")"

temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM

cp elm.json "$temporary_directory/"
(
  cd "$temporary_directory"
  elm2nix convert > elm-srcs.nix
  elm2nix snapshot
  nixfmt elm-srcs.nix
)

mv "$temporary_directory/elm-srcs.nix" elm-srcs.nix
mv "$temporary_directory/registry.dat" registry.dat
