{
  description = "PREEM full-stack web application";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    fenix = {
      url = "fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "flake-utils";
    pgdb = {
      url = "github:mbr/pgdb-rs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      fenix,
      flake-utils,
      pgdb,
      ...
    }:
    let
      appModule = import ./nixos-module.nix { inherit self; };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        toolchain = fenix.packages.${system}.stable.withComponents [
          "cargo"
          "clippy"
          "rust-analyzer"
          "rust-src"
          "rustc"
          "rustfmt"
        ];
        rustPlatform = pkgs.makeRustPlatform {
          cargo = toolchain;
          rustc = toolchain;
        };
        rustEnv = {
          RUSTFLAGS = pkgs.lib.optionalString pkgs.stdenv.isLinux "-Clink-self-contained=-linker";
          OPENSSL_NO_VENDOR = "1";
          SQLX_OFFLINE = "true";
        };
        sqlxDependency = (pkgs.lib.importTOML ./backend/Cargo.toml).dependencies.sqlx;
        sqlxVersion = pkgs.lib.removePrefix "=" sqlxDependency.version;
        sqlxCli =
          assert pkgs.sqlx-cli.version == sqlxVersion;
          pkgs.sqlx-cli;
        backend = pkgs.callPackage ./backend/package.nix {
          inherit rustEnv rustPlatform;
        };
        frontend = pkgs.callPackage ./frontend/package.nix { };
        name = (pkgs.lib.importTOML ./backend/Cargo.toml).package.name;
        app = pkgs.symlinkJoin {
          name = "${name}-full";
          paths = [ backend ];
          postBuild = ''
            mkdir -p $out/share/${name}
            ln -s ${frontend} $out/share/${name}/frontend
          '';
          meta = backend.meta // {
            mainProgram = name;
          };
        };
      in
      {
        checks = {
          default = app;
        }
        // pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
          nixos-module-integration = pkgs.testers.runNixOSTest (
            import ./nixos-test.nix { inherit appModule; }
          );
        };

        devShells.default = pkgs.mkShell (
          rustEnv
          // {
            inputsFrom = [
              backend
              frontend
            ];
            packages = with pkgs; [
              elm2nix
              elmPackages.elm
              elmPackages.elm-format
              esbuild
              nixfmt
              pgdb.packages.${system}.default
              postgresql
              python3Packages.ephemeral-port-reserve
              process-compose
              sqlxCli
              tailwindcss_4
              toolchain
            ];
          }
        );

        formatter = pkgs.writeShellScriptBin "preem-format" ''
          set -eu
          export PATH="${toolchain}/bin:$PATH"
          cargo fmt --manifest-path backend/Cargo.toml -- \
            --config group_imports=StdExternalCrate \
            --config imports_granularity=Crate
          ${pkgs.elmPackages.elm-format}/bin/elm-format --yes frontend/src
          ${pkgs.nixfmt}/bin/nixfmt \
            flake.nix \
            nixos-module.nix \
            nixos-test.nix \
            backend/package.nix \
            frontend/elm-srcs.nix \
            frontend/package.nix
        '';

        packages = {
          default = app;
          inherit backend frontend;
        };
      }
    )
    // {
      nixosModules.default = appModule;
    };
}
