# Project operations

## Development helpers

Running `just dev` builds and runs a complete local development instance,
including PostgreSQL. It prints the backend and PostgreSQL ports, which are
assigned dynamically so multiple working copies can run on the same machine.
Run `just down` to stop the instance.

After making changes, run `just format`, `just check`, and `just test` to format
the sources, run static and build checks, and execute the test suite. Run
`just flake-check` to validate formatting and Nix integration. Bare `just`
lists all repository-wide commands.

After changing `frontend/elm.json`, run `just update-deps` from `frontend/` to
refresh the Nix dependency snapshot.

The frontend build places each asset set under its aggregate version in
`dist/static`, injects that version into `dist/index.html`, and writes it to
`dist/static/frontend-version`. The backend adds that version to API responses
so a running Elm application can offer to reload after a frontend rebuild.

The HTTP API contract is mirrored in `backend/src/api.rs` and
`frontend/src/Api.elm`. Keep the serialized Rust types and Elm decoders in sync.

## Database changes

Prefer SQLx's compile-time checked query macros for database access, and keep
the generated `.sqlx` metadata committed.

Create migrations from `backend/`:

```sh
just add-migration <name>
```

After changing migrations or checked queries, apply the migrations to a fresh
temporary database and refresh the committed query metadata from `backend/`:

```sh
just prepare
```

## Deployment

`just package` creates the combined production package. NixOS deployments
should use the service module exported as `nixosModules.default`, which
generates the application configuration and runs that package.
