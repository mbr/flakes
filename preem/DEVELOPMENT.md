# Project operations

## Development helpers

Running `./dev.sh` builds and runs a complete local development instance,
including PostgreSQL. It prints the backend and PostgreSQL ports, which are
assigned dynamically so multiple working copies can run on the same machine.
Run `process-compose down` to stop the instance.

After making changes, run `./format.sh && ./check.sh && ./test.sh` to format the
sources, run static and build checks, and execute the test suite. After changing
Nix packaging or the NixOS module, also run `nix flake check`.

After changing `frontend/elm.json`, run `./frontend/update-elm-deps.sh` to
refresh the Nix dependency snapshot.

The frontend build fingerprints its JavaScript and CSS assets, injects their
names and an aggregate version into `dist/index.html`, and writes the version
to `dist/frontend-version`. The backend adds that version to API responses so
a running Elm application can offer to reload after a frontend rebuild.

The HTTP API contract is mirrored in `backend/src/api.rs` and
`frontend/src/Api.elm`. Keep the serialized Rust types and Elm decoders in sync.

## Database changes

Prefer SQLx's compile-time checked query macros for database access, and keep
the generated `.sqlx` metadata committed.

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

## Deployment

`nix build` creates the combined production package. NixOS deployments should
use the service module exported as `nixosModules.default`, which generates the
application configuration and runs that package.
