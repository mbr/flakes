# Project operations

## Development helpers

Running `./dev.sh` builds and runs a complete local development instance,
including PostgreSQL. It prints the backend and PostgreSQL ports, which are
assigned dynamically so multiple working copies can run on the same machine.
Run `process-compose down` to stop the instance.

## Database changes

Create migrations from `backend/`:

```sh
cargo sqlx migrate add <name>
```

Refresh committed query metadata against the development database using the
PostgreSQL port reported by `./dev.sh`:

```sh
cd backend
DATABASE_URL=postgres://dev:dev@127.0.0.1:<port>/dev cargo sqlx prepare
```

## Validation and formatting

- `./check.sh` checks formatting, compilation, lints, and the frontend build.
- `./tests.sh` runs the test suite.
- `./format.sh` formats Rust, Elm, and Nix sources.
- `./frontend/update-elm-deps.sh` refreshes the Nix dependency snapshot after
  changing `frontend/elm.json`.

Run checks before formatting final changes.

## Build and deployment

- `nix flake check` builds all packages and evaluates the NixOS module.
- `nix build` creates the combined production package.
- `nix run -- <config.toml>` runs the combined package with explicit
  configuration.
- The flake exports the service module as `nixosModules.default`. The module
  generates the application configuration and runs the combined package.
