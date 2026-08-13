#!/bin/sh

#: Runs project static and build checks.

set -eu

cd "$(dirname "$0")"

./backend/check.sh
./frontend/check.sh
