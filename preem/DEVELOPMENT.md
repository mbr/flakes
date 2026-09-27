# Project operations

Set `package.name` in `backend/Cargo.toml`, then run `just build` to refresh
`backend/Cargo.lock`. Packages, services, paths, and tests derive their names
from it; customize page titles and descriptions separately. Renaming an
existing deployment changes its service and default database identity and
requires migration.

## Development

`just dev` builds and runs the app with temporary PostgreSQL and a dynamically
assigned localhost port printed in the logs. Working copies can run concurrently;
`Ctrl-C` stops the app and removes its database. Bare `just` lists commands.

After changes, run `just check`, `just test`, and `just flake-check` for static,
build, test, formatting, and Nix integration checks, then `just format`.
After editing `frontend/elm.json`, run `just update-deps` in `frontend/` to
refresh Nix dependency snapshots.

Frontend assets live under `dist/static/<version>`. The build embeds the version
in `dist/index.html` and writes `dist/frontend-version`; API responses carry it
so Elm can offer a reload after deployment.

Keep Rust API types in `backend/src/api.rs` synchronized with Elm decoders in
`frontend/src/Api.elm`.

## UI conventions

Use `ChadCn` wherever it covers the UI. Inspect the installed package's exposed
modules and APIs before building custom components; do not recreate its components.
Extract repeated markup, styling, and interaction logic into reusable Elm view
functions or modules with explicit data and message parameters.

Style Elm views with Tailwind utilities and semantic tokens from
`frontend/css/input.css`, not global style rules or a parallel CSS component-class
system. Reserve custom CSS for theme configuration and behavior utilities cannot
reasonably express.

Prefer Tailwind spacing/sizing scales and responsive layouts over pixel-tuned
values such as `w-[347px]`. Use arbitrary values only when utilities or theme
tokens cannot express the requirement; arbitrary variants like `[&>svg]:size-4`
are fine.

## Database

Prefer SQLx compile-time checked query macros and commit generated `.sqlx`
metadata. From `backend/`, use `just add-migration <name>` to create migrations.
After changing migrations or checked queries, run `just prepare` to apply
migrations to a temporary database and regenerate metadata.

## Deployment

`just package` builds the combined production package. Deploy through
`nixosModules.default`, which generates configuration and runs the package.

## Secrets and external values

Use `twelve::config::external::External` for literal-or-file strings; prefer
files for secrets and literals for public dummy/development values. For secrets,
add this dependency to `backend/Cargo.toml`:

```toml
sec = { version = "1.1", features = ["deserialize"] }
```

Wrap sensitive fields in `sec::Secret<External>`. Deserialization does not read
files; resolve them at startup without unwrapping the secret:

```rust
let token: Secret<String> = credentials.api_token.try_map_revealed(External::load)?;
```

TOML accepts `api_token = "dummy-dev-key"` or
`api_token = { file = "/run/secrets/api-token" }`. Files must be UTF-8;
loading preserves whitespace, and relative paths use the application's working
directory. `Secret` redacts debug output, but TOML parse errors may expose source.

In `nixos-module.nix`, generate a path reference, never a real token:

```nix
api_token.file = "/run/credentials/${name}.service/api-token";
```

Supply the credential through systemd using
[nixdrawer's credential documentation](https://github.com/mbr/nixdrawer#credentials).
