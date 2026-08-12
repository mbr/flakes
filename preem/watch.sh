#!/bin/sh
set -eu

cd "$(dirname "$0")"

exec watchexec --restart \
  --watch build.sh \
  --watch backend/Cargo.toml \
  --watch backend/Cargo.lock \
  --watch backend/migrations \
  --watch backend/src \
  --watch frontend/build.sh \
  --watch frontend/elm.json \
  --watch frontend/src \
  --watch frontend/css \
  --watch frontend/public \
  --debounce 1s \
  -- ./build.sh
