# Development

This Elm frontend uses stock Elm tooling, Tailwind CSS, and Nix.

Enter the development environment with:

```sh
nix develop
```

## Commands

- `nix fmt` formats Elm and Nix sources.
- `./check.sh` checks formatting and builds the development application.
- `./build.sh` builds the development application in `dist/`.
- `./build.sh --release` builds the optimized application in `dist/`.
- `./dev.sh` builds and serves the application on port 3000.
- `./update-elm-deps.sh` updates the Nix dependency sources from `elm.json`.
- `nix build` creates an optimized application package.

For rebuilds while editing, run:

```sh
watchexec -r -e css,elm,html,json -d 1 ./dev.sh
```

After changing dependencies with `elm install`, run `./update-elm-deps.sh` from the development environment.
