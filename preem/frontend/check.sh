#!/bin/sh
set -eu

cd "$(dirname "$0")"

./format.sh --check
./build.sh
