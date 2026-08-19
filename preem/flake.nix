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
    nixdrawer = {
      url = "github:mbr/nixdrawer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
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
      nixdrawer,
      treefmt-nix,
      ...
    }:
    let
      appModule = import ./nixos-module.nix { inherit self nixdrawer; };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        buildToolchain = fenix.packages.${system}.stable.minimalToolchain;
        devToolchain = fenix.packages.${system}.stable.withComponents [
          "cargo"
          "clippy"
          "rust-analyzer"
          "rust-src"
          "rustc"
          "rustfmt"
        ];
        rustPlatform = pkgs.makeRustPlatform {
          cargo = buildToolchain;
          rustc = buildToolchain;
        };
        rustEnv = {
          RUSTFLAGS =
            pkgs.lib.optionalString pkgs.stdenv.isLinux "-Clink-self-contained=-linker "
            # Avoid runtime references from embedded toolchain source paths.
            + "--remap-path-prefix=${buildToolchain}=/rustc";
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
        treefmtEval = treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs = {
            elm-format.enable = true;
            nixfmt.enable = true;
            rustfmt = {
              enable = true;
              edition = "2024";
              package = devToolchain;
            };
          };
          settings.formatter.rustfmt.options = [
            "--config"
            "group_imports=StdExternalCrate"
            "--config"
            "imports_granularity=Crate"
          ];
        };
      in
      {
        checks = {
          default = app;
          formatting = treefmtEval.config.build.check self;
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
            nativeBuildInputs = with pkgs; [
              elm2nix
              elmPackages.elm
              esbuild
              just
              pgdb.packages.${system}.default
              postgresql
              sqlxCli
              tailwindcss_4
              devToolchain
            ];
          }
        );

        formatter = treefmtEval.config.build.wrapper;

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
