# Development guidance

## Workflow

The development setup is contained to a single worktree, sans the TCP bind address used for the web application. However the latter defaults to `127.0.0.1:0`, thus can be expected to be conflict free. The app's listening port is printed in its logs or can be retrieved using `process-compose process ports web`.

To run the entire app in development mode, including a database

- build it using `just build`, then
- run it using `process-compose up` (append `--tui=false` if you want to run headless).

Set `BIND_ADDRESS=` to a known address if you need a deterministic or non-localhost bind address for the web application.

After changes, run `just format`, `just check`, then `just test`. The frontend will reload automatically after building, the backend requires a `process-compose process restart web`.

After editing `frontend/elm.json`, run `just update-deps` in `frontend/` and commit the refreshed dependency snapshots. Always keep `backend/src/api.rs` and `frontend/src/Api.elm` synchronized.

## UI conventions

Use `ChadCn` wherever it covers the UI. Inspect its installed modules and APIs before building custom components; do not recreate what it provides. Extract repeated markup, styling, and interaction logic into reusable Elm view functions or modules with explicit data and message parameters.

Use Tailwind utilities and semantic tokens from `frontend/css/input.css`, not global style rules or a parallel CSS component-class system. Reserve custom CSS for theme configuration and behavior utilities cannot reasonably express.

Prefer Tailwind spacing/sizing scales and responsive layouts over pixel-tuned values such as `w-[347px]`. Use arbitrary values only when utilities or theme tokens cannot express the requirement; arbitrary variants like `[&>svg]:size-4` are fine.

## Database

Prefer SQLx compile-time checked query macros. After changing migrations or checked queries, run `just prepare` in `backend/` and commit the regenerated `.sqlx` metadata.

`pgdb --connect .dev/db <command>` can be used to run a command against the database, provided it has been started using process-compose. `just prepare` still uses a disposable database.

## Secrets

Use `twelve::config::external::External` for literal-or-file strings. Wrap sensitive fields in `sec::Secret<External>`; add `sec` with its `deserialize` feature. Prefer files for secrets and literals for public dummy values. Deserialization does not read files; resolve them at startup while retaining the secret wrapper:

```rust
let token: Secret<String> = credentials.api_token.try_map_revealed(External::load)?;
```

TOML accepts `api_token = "dummy-dev-key"` or `api_token = { file = "/run/secrets/api-token" }`. Files must be UTF-8; whitespace is preserved, and relative paths use the application's working directory. `Secret` redacts debug output, but TOML parse errors may expose source.

Never put secret values in generated Nix configuration. In `nixos-module.nix`, reference `/run/credentials/${name}.service/<credential>` and supply the file via [nixdrawer's systemd credential support](https://github.com/mbr/nixdrawer#credentials).
