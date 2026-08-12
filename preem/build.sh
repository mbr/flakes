#!/bin/sh
set -eu

cd "$(dirname "$0")"

./backend/build.sh "$@"
./frontend/build.sh "$@"
