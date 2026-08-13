#!/bin/sh

#: Lints all backend targets.

set -eu

cd "$(dirname "$0")"

cargo clippy --all-targets -- -D warnings
