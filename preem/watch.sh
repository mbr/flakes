#!/bin/sh
set -eu

cd "$(dirname "$0")"

case "${1:-}" in
  backend)
    exec watchexec --restart \
      --watch build.sh \
      --watch backend/Cargo.toml \
      --watch backend/Cargo.lock \
      --watch backend/migrations \
      --watch backend/src \
      --debounce 1s \
      -- ./build.sh backend
    ;;
  frontend)
    exec watchexec --restart \
      --watch build.sh \
      --watch frontend/build.sh \
      --watch frontend/elm.json \
      --watch frontend/src \
      --watch frontend/css \
      --watch frontend/public \
      --debounce 1s \
      -- ./build.sh frontend
    ;;
  *)
    echo "usage: ./watch.sh {backend|frontend}" >&2
    exit 2
    ;;
esac
