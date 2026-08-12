# Project operations

## Development helpers

Run `./build.sh` to build the debug backend and frontend. Run
`./build.sh --release` to build both in release mode. The frontend output is
written to `frontend/dist`, while Cargo writes the backend to `backend/target`.

Run `./watch.sh` to rerun `./build.sh` when backend or frontend inputs change.
This script only builds artifacts; it does not start or restart the development
services.

Run `./dev.sh` after an initial build to start Process Compose in the
background. It starts ephemeral PostgreSQL and the existing debug backend
binary, waits for the backend to listen, and prints their dynamically allocated
ports. Dynamic ports allow concurrent checkouts and worktrees.

Process Compose reads `process-compose.yaml`. It passes development
configuration to the backend as TOML on standard input. It does not build the
application or restart the backend after a new build. Restart the backend with
`process-compose process restart backend`; rebuilt frontend assets are served
from `frontend/dist` without a backend restart.

The direnv environment configures Process Compose to use
`.process_compose/process-compose.sock` for its control API and
`.process_compose/process-compose.log` for logs. The directory is local runtime
state and is ignored by Git. Common commands are:

```sh
process-compose process list
process-compose process ports backend
process-compose process logs backend
process-compose process restart backend
process-compose down
```

The backend otherwise takes one mandatory configuration argument. A path loads
a TOML file; `-` loads TOML from standard input.

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
