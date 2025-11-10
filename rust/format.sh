#!/bin/sh

#: Formats the source.
#: Uses --config to override rustfmt settings without nightly toolchain

exec cargo fmt -- --config group_imports=StdExternalCrate --config imports_granularity=Crate $@
