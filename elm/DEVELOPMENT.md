# Development

This tailwind-enabled frontend application in Elm is built using stock Elm tools and `nix`. Use

* `nix build` to build a release package, or
* `nix develop` to enter a development shell.

Note that when adding any dependency via `elm install`, the `update-elm-deps.sh` script must be
called inside a `nix develop` shell.

## Commands

- `./format.sh` to reformat sources.
- `./format.sh --check` to check formatting.
- `./build.sh` to build a development version of the app.
- `./build.sh --release` to build a release version without using `nix build`.
- `./update-elm-deps.sh` to update the nix Elm dependencies using `elm.json`.
