#!/bin/sh
set -eu

cd "$(dirname "$0")"

rm -rf dist
mkdir -p dist
cp -R public/. dist/

build() {
  elm make src/Main.elm "$1" --output=dist/app.js
  shift

  elm_chadcn_version=$(awk -F '"' '/"mbr\/elm-chadcn"/ { print $4; exit }' elm.json)
  elm_home=${ELM_HOME:-"$HOME/.elm"}
  elm_chadcn_source="$elm_home/0.19.1/packages/mbr/elm-chadcn/$elm_chadcn_version/src/ChadCn"
  if [ ! -d "$elm_chadcn_source" ]; then
    echo "elm-chadcn source not found at $elm_chadcn_source" >&2
    exit 1
  fi
  ln -sfn "$elm_chadcn_source" elm-stuff/chadcn-source

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
