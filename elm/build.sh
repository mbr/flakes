#!/bin/sh
set -eu

cd "$(dirname "$0")"

rm -rf dist
mkdir -p dist
cp -R public/. dist/

build() {
  elm make src/Main.elm "$1" --output=dist/app.js
  shift
  tailwindcss -i css/input.css -o dist/app.css "$@"
}

case "${1:-}" in
  --release)
    build --optimize --minify
    ;;
  "")
    build --debug
    ;;
  *)
    echo "usage: ./build.sh [--release]" >&2
    exit 2
    ;;
esac
