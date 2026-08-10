# Rust and Elm web application

A full-stack application with an Axum backend, Elm frontend, Tailwind CSS, and reproducible Nix builds.

## Initial setup

1. Restore script permissions with `chmod +x ./*.sh frontend/*.sh`.
2. Replace `myapp` in `backend/Cargo.toml`, `flake.nix`, and `nixos-module.nix`.
3. Update the package descriptions and the frontend document title.
4. Run `direnv allow` or enter the environment with `nix develop`.

The generated project intentionally has no database, authentication, or domain architecture. Add those when the application requires them.

## Development

Start the backend and frontend watchers:

```sh
process-compose up
```

The backend serves both the API and the compiled frontend at <http://127.0.0.1:3000>.

Useful commands:

- `./check.sh` validates formatting, tests, lints, and builds the development frontend.
- `./format.sh` formats Rust, Elm, and Nix sources.
- `nix flake check` builds every package and evaluates the NixOS module.
- `nix build` creates the combined production package.
- `nix run` runs the combined package.
- `./frontend/update-elm-deps.sh` updates the Nix Elm dependency snapshot after `elm.json` changes.

## API contract

`backend/src/api.rs` and `frontend/src/Api.elm` are the two sides of the checked-in HTTP contract. Keep response fields, error codes, Serde configuration, Elm types, and Elm decoders synchronized explicitly.

The template provides:

- `GET /api/status` as a minimal end-to-end request.
- Structured JSON errors with stable codes.
- A frontend error model that preserves HTTP status and response bodies.
- A reusable Elm JSON response decoder.

Add resource-specific submodules only when the initial files become unwieldy. The transport contract should remain separate from domain models and persistence decisions.

## Frontend components

`ChadCn.Alert` and `ChadCn.Button` establish the reusable component conventions without importing a complete component catalogue. Their semantic colors and component rules live in `frontend/css/input.css`.

## Deployment

The flake exports `nixosModules.default`. A minimal deployment looks like:

```nix
{
  inputs.myapp.url = "github:example/myapp";

  outputs = { myapp, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      modules = [
        myapp.nixosModules.default
        {
          services.myapp = {
            enable = true;
            bindAddress = "127.0.0.1:3000";
          };
        }
      ];
    };
  };
}
```

The service is unprivileged and systemd-hardened. Put a reverse proxy and authentication boundary in front of it when exposing it beyond a trusted network.
