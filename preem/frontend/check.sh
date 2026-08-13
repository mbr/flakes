#!/bin/sh

#: Builds the frontend assets.

set -eu

cd "$(dirname "$0")"

./build.sh
