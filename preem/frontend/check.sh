#!/bin/sh

#: Checks frontend formatting and builds its assets.

set -eu

cd "$(dirname "$0")"

./format.sh --check
./build.sh
