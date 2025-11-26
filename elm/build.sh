#!/bin/sh

#: Build the application, including CSS. Supports `--release`.

set -e

if [ "$1" = "--release" ]; then
    ELM_OPTS="--optimize"
    TAILWIND_OPTS="--minify"
else
    ELM_OPTS="--debug"
    TAILWIND_OPTS=""
fi

elm make src/Main.elm $ELM_OPTS --output=main.js
tailwindcss -i ./src/input.css -o ./style.css $TAILWIND_OPTS
