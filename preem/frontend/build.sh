#!/bin/sh
set -eu

cd "$(dirname "$0")"

rm -rf dist
mkdir -p dist
cp -R public/. dist/

case "${1:-}" in
  --release)
    elm_flag=--optimize
    minify_flag=--minify
    ;;
  "")
    elm_flag=--debug
    minify_flag=
    ;;
  *)
    echo "usage: ./build.sh [--release]" >&2
    exit 2
    ;;
esac

elm make src/Main.elm "$elm_flag" --output=elm-stuff/app.js
# Reprint Elm's JavaScript so Tailwind can recognize escaped class names.
esbuild elm-stuff/app.js --outfile=dist/app.js --log-level=warning $minify_flag
tailwindcss -i css/input.css -o dist/app.css $minify_flag
