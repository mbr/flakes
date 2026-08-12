#!/bin/sh

#: Formats the backend source.
#: Uses --config to override rustfmt settings without a nightly toolchain.
#: As a little hack, supports `--check`.

cd "$(dirname "$0")"

cargo fmt -- --config group_imports=StdExternalCrate --config imports_granularity=Crate "$@"
nixfmt "$@" package.nix
