# Project operations

Set the application name with `package.name` in `backend/Cargo.toml`, then run
`just build` to refresh `backend/Cargo.lock`. Packages, NixOS services, paths,
and integration tests derive their names from that value. Update page titles
and descriptions separately.

Renaming an existing deployment changes its service and default database
identity; migrate the deployment rather than treating it as a routine rebuild.

## Development helpers

Running `just dev` builds and runs the application with a fresh temporary
PostgreSQL database. The backend logs its dynamically assigned port, allowing
multiple working copies to run concurrently. Press `Ctrl-C` to stop the
application and remove its database.

After making changes, run `just format`, `just check`, and `just test` to format
the sources, run static and build checks, and execute the test suite. Run
`just flake-check` to validate formatting and Nix integration. Bare `just`
lists all repository-wide commands.

After changing `frontend/elm.json`, run `just update-deps` from `frontend/` to
refresh the Nix dependency snapshot.

The frontend build places each asset set under its aggregate version in
`dist/static`, injects that version into `dist/index.html`, and writes it to
`dist/frontend-version`. The backend adds that version to API responses
so a running Elm application can offer to reload after a frontend rebuild.

The HTTP API contract is mirrored in `backend/src/api.rs` and
`frontend/src/Api.elm`. Keep the serialized Rust types and Elm decoders in sync.

## UI conventions

Use `ChadCn` components wherever they cover the required UI. Inspect the
installed package's exposed modules and APIs before building a custom
component; do not recreate components the library already provides.

Build reusable Elm view functions or modules for repeated UI patterns, with
explicit parameters for their data and messages. Do not copy-paste markup,
styling, or interaction logic across views.

Style layouts and custom elements with Tailwind utility classes in Elm views,
using the semantic theme tokens in `frontend/css/input.css`. Do not bypass
Tailwind with global style rules or a parallel CSS component-class system.
Limit custom CSS to theme configuration and behavior utilities cannot
reasonably express.

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

## Secrets and external values

Use `twelve::config::external::External` for strings supplied directly or
through a file. Prefer files for secrets and literals for public dummy or
development values. For secrets, add this dependency to `backend/Cargo.toml`:

```toml
sec = { version = "1.1", features = ["deserialize"] }
```

Wrap sensitive configuration fields in `Secret<External>`. For example:

```rust
use sec::Secret;
use serde::Deserialize;
use twelve::config::external::External;

/// Selects credentials for an external API.
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct Credentials {
    /// Selects the API token source.
    api_token: Secret<External>,
}
```

Deserialization does not read files. Resolve the source explicitly at
startup, keeping the result wrapped:

```rust
let token: Secret<String> = credentials.api_token.try_map_revealed(External::load)?;
```

Use either of these TOML forms:

```toml
api_token = "dummy-dev-key"
# Alternatively: api_token = { file = "/run/secrets/api-token" }
```

Loading preserves whitespace, including trailing newlines. Files must be
UTF-8; relative paths use the application's working directory. `Secret`
redacts debug output, but TOML parse errors can still expose source excerpts.

For NixOS deployment, add a file reference to the TOML attributes generated
in `nixos-module.nix`:

```nix
api_token.file = "/run/credentials/${name}.service/api-token";
```

Supply that credential through systemd as described in
[nixdrawer's credential documentation](https://github.com/mbr/nixdrawer#credentials).
Only the path belongs in the generated configuration, never a real token.
