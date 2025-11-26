# Development

This tailwind-enabled frontend application in Elm is built using stock Elm tools and `nix`. Use

* `nix build` to build a release package, or
* `nix develop` to enter a development shell.

Inside, use

## Commands

- `./format.sh` to reformat sources.
- `./format.sh --check` to check formatting.
- `./build.sh` to build a development version of the app.
- `./build.sh --release` to build a release version without using `nix build`.
