#!/bin/sh
set -eu

cd "$(dirname "$0")"

./build.sh
exec python3 -m http.server 3000 --directory dist
