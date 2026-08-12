# Flake template from: https://github.com/mbr/flakes

{
  description = "A collection of flake templates";

  outputs =
    { self }:
    {
      templates.rust = {
        path = ./rust;
        description = "A Rust project";
        welcomeText = ''
          # Rust project

          Uses Fenix to provide Rust, self-contained flake.

          ## Next steps (recommended)

          * Edit `Cargo.toml`
          * Add native build dependencies to `flake.nix` (if any)
          * (potentially) Change the pinned NixOS version, also in `flake.nix`.

          ## Development

          `nix develop` to enter a dev shell

          ## Building the derivation

          * `nix build` to build the derivation, `result/bin/..` will contain your binary
        '';
      };
      templates.problem-bench = {
        path = ./problem-bench;
        description = "A Rust benchmarking problem workspace";
        welcomeText = ''
          # Rust problem benchmarking workspace

          Provides reference and candidate binaries plus correctness, benchmarking, and profiling tools.

          ## Next steps

          * Edit `Cargo.toml` and replace the sample binaries.
          * Adapt `src/bin/generate-test-data.rs` and `expected-results.txt`.
          * Run `cargo run --release --bin generate-test-data` to create workloads.
          * Run `./test.sh target/release/wip` and `./bench.sh wip`.

          See `README.md` for the complete workflow.
        '';
      };
      templates.python = {
        path = ./python;
        description = "A Python application";
        welcomeText = ''
          # Python application

          Uses nix-managed Python dependencies for a Python application.

          ## Next steps (recommended)

          * Rename `src/myproject`
          * Edit `name` and scripts section in `pyproject.toml`
          * Add additional dependencies to `flake.nix` (if any)
          * (potentially) Change the pinned NixOS version, also in `flake.nix`.

          ## Development

          `nix develop` to enter a dev shell

          ## Building the derivation

          * `nix build` to build the derivation, `result/bin/..` will contain your binary
          * Alternatively `nix build '#docker'` will build a docker image (load it with `podman/docker load -i result`)
        '';
      };
      templates.elm = {
        path = ./elm;
        description = "An Elm project";
        welcomeText = ''
          # Elm project

          Uses stock Elm along with `tailwindcss`.

          ## Next steps (recommended)

          * Restore script permissions with `chmod +x ./*.sh`.
          * Edit `flake.nix`, at minimum set the package name.
          * Add native build dependencies (if any)
          * (potentially) Change the pinned NixOS version, also in `flake.nix`.

          ## Development

          See `DEVELOPMENT.md` for details.
        '';
      };
      templates.preem = {
        path = ./preem;
        description = "A PREEM full-stack web application";
        welcomeText = ''
          # PREEM web application

          PREEM combines PostgreSQL, Rust, Elm, and environment management powered by Nix, with Axum and Tailwind CSS.

          ## Setup

          * Restore script permissions with `chmod +x ./*.sh backend/*.sh frontend/*.sh`.
          * Replace `myapp` in the Rust package, flake, and NixOS module.
          * Update the package descriptions and frontend document title.
          * Run `direnv allow` before starting Process Compose.

          ## Development

          * `./dev.sh` starts ephemeral PostgreSQL plus the backend and frontend watchers.
          * It reports dynamically assigned ports so concurrent checkouts can run without conflicts.
          * `process-compose down` stops the development stack.
          * `cargo sqlx migrate add <name>` creates a migration from `backend/`.
          * `cargo sqlx prepare` refreshes committed query metadata while the development stack runs.
          * `./check.sh` quickly validates formatting, compilation, lints, and the frontend build.
          * `./tests.sh` runs the test suite.
          * `./format.sh` formats Rust, Elm, and Nix sources.
          * `./frontend/update-elm-deps.sh` updates the Nix snapshot after changing `elm.json`.

          ## Build and deployment

          * `nix flake check` builds all packages and evaluates the NixOS module.
          * `nix build` creates the combined production package.
          * `nix run` runs the combined package.
          * The flake exports the service module as `nixosModules.default`.
        '';
      };

      templates.default = self.templates.rust;
    };
}
