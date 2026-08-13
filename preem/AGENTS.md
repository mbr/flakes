# Project operations

## Development helpers

Running `./dev.sh` builds and runs a complete local development instance,
including PostgreSQL. It prints the backend and PostgreSQL ports, which are
assigned dynamically so multiple working copies can run on the same machine.
Run `process-compose down` to stop the instance.

After making changes, run `./format.sh && ./check.sh && ./test.sh` to format the
sources, run static and build checks, and execute the test suite.

After changing `frontend/elm.json`, run `./frontend/update-elm-deps.sh` to
refresh the Nix dependency snapshot.

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

## Build and deployment

- `nix flake check` builds all packages and evaluates the NixOS module.
- `nix build` creates the combined production package.
- `nix run -- <config.toml>` runs the combined package with explicit
  configuration.
- The flake exports the service module as `nixosModules.default`. The module
  generates the application configuration and runs the combined package.
