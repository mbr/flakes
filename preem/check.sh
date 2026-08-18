#!/bin/sh

#: Runs project static and build checks.

set -eu

cd "$(dirname "$0")"

just --justfile backend/justfile check
just --justfile frontend/justfile check
