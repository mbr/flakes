#!/bin/sh

#: Formatting script. Supports --check.

set -e

ELM_FORMAT_FLAGS="--yes"
NIXFMT_FLAGS=""

if [ "$1" = "--check" ]; then
    ELM_FORMAT_FLAGS="--validate"
    NIXFMT_FLAGS="--check"
fi

elm-format $ELM_FORMAT_FLAGS src/
nixfmt $NIXFMT_FLAGS flake.nix elm-srcs.nix
