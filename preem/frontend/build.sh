#!/bin/sh
set -eu

cd "$(dirname "$0")"

rm -rf dist
mkdir -p dist
cp -R public/. dist/
rm dist/index.html

case "${1:-}" in
  --release) elm_flag=--optimize; minify_flag=--minify ;;
  "") elm_flag=--debug; minify_flag= ;;
  *) echo "usage: ./build.sh [--release]" >&2; exit 2 ;;
esac

elm make src/Main.elm "$elm_flag" --output=elm-stuff/app.js
# Reprint Elm's JavaScript so Tailwind can recognize escaped class names.
esbuild elm-stuff/app.js --outfile=dist/app.js --log-level=warning $minify_flag
tailwindcss -i css/input.css -o dist/app.css $minify_flag

js_hash=$(sha256sum dist/app.js | cut -d ' ' -f 1)
css_hash=$(sha256sum dist/app.css | cut -d ' ' -f 1)
template_hash=$(sha256sum public/index.html | cut -d ' ' -f 1)
frontend_version=$(
  printf '%s\n%s\n%s\n' "$js_hash" "$css_hash" "$template_hash" \
    | sha256sum \
    | cut -d ' ' -f 1
)
js_name="app-$js_hash.js"
css_name="app-$css_hash.css"

mv dist/app.js "dist/$js_name"
mv dist/app.css "dist/$css_name"
sed \
  -e "s/__APP_JS__/$js_name/g" \
  -e "s/__APP_CSS__/$css_name/g" \
  -e "s/__FRONTEND_VERSION__/$frontend_version/g" \
  public/index.html > dist/index.html.tmp

printf '%s\n' "$frontend_version" > dist/frontend-version.tmp
mv dist/frontend-version.tmp dist/frontend-version
mv dist/index.html.tmp dist/index.html
