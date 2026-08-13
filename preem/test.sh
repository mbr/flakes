#!/bin/sh
set -eu

cd "$(dirname "$0")"

./backend/test.sh
