{
  description = "Rust and Elm full-stack web application";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    fenix = {
      url = "fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      fenix,
      ...
    }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      eachSystem = nixpkgs.lib.genAttrs systems;
      pkgsFor = eachSystem (system: nixpkgs.legacyPackages.${system});
      toolchainFor = eachSystem (
        system:
        fenix.packages.${system}.stable.withComponents [
          "cargo"
          "clippy"
          "rust-analyzer"
          "rust-src"
          "rustc"
          "rustfmt"
        ]
      );
      rustPlatformFor = eachSystem (
        system:
        pkgsFor.${system}.makeRustPlatform {
          cargo = toolchainFor.${system};
          rustc = toolchainFor.${system};
        }
      );
      rustEnvFor = eachSystem (system: {
        RUSTFLAGS =
          pkgsFor.${system}.lib.optionalString pkgsFor.${system}.stdenv.isLinux
            "-Clink-self-contained=-linker";
        OPENSSL_NO_VENDOR = "1";
      });
      backendFor = eachSystem (
        system:
        pkgsFor.${system}.callPackage ./backend/package.nix {
          rustEnv = rustEnvFor.${system};
          rustPlatform = rustPlatformFor.${system};
        }
      );
      frontendFor = eachSystem (system: pkgsFor.${system}.callPackage ./frontend/package.nix { });
      appFor = eachSystem (
        system:
        let
          pkgs = pkgsFor.${system};
          backend = backendFor.${system};
          frontend = frontendFor.${system};
          name = (pkgs.lib.importTOML ./backend/Cargo.toml).package.name;
        in
        pkgs.symlinkJoin {
          name = "${name}-full";
          paths = [ backend ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/${name} \
              --set APP_FRONTEND ${frontend}
          '';
          meta = backend.meta // {
            mainProgram = name;
          };
        }
      );
      appModule = import ./nixos-module.nix { inherit self; };
      moduleTestFor =
        system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            appModule
            {
              services.myapp.enable = true;
              system.stateVersion = "26.05";
            }
          ];
        };
    in
    {
      checks = eachSystem (
        system:
        {
          default = appFor.${system};
          backend = backendFor.${system};
          frontend = frontendFor.${system};
        }
        // nixpkgs.lib.optionalAttrs pkgsFor.${system}.stdenv.isLinux {
          nixos-module = (moduleTestFor system).config.systemd.units."myapp.service".unit;
        }
      );

      devShells = eachSystem (system: {
        default = pkgsFor.${system}.mkShell (
          rustEnvFor.${system}
          // {
            inputsFrom = [
              backendFor.${system}
              frontendFor.${system}
            ];
            packages = with pkgsFor.${system}; [
              elm2nix
              elmPackages.elm
              elmPackages.elm-format
              nixfmt
              process-compose
              tailwindcss_4
              toolchainFor.${system}
              watchexec
            ];
            APP_BIND_ADDRESS = "127.0.0.1:3000";
            APP_FRONTEND = "../frontend/dist";
            RUST_LOG = "myapp=debug,tower_http=debug";
          }
        );
      });

      formatter = eachSystem (
        system:
        pkgsFor.${system}.writeShellScriptBin "rust-elm-format" ''
          set -eu
          export PATH="${toolchainFor.${system}}/bin:$PATH"
          cargo fmt --manifest-path backend/Cargo.toml -- \
            --config group_imports=StdExternalCrate \
            --config imports_granularity=Crate
          ${pkgsFor.${system}.elmPackages.elm-format}/bin/elm-format --yes frontend/src
          ${pkgsFor.${system}.nixfmt}/bin/nixfmt \
            flake.nix \
            nixos-module.nix \
            backend/package.nix \
            frontend/elm-srcs.nix \
            frontend/package.nix
        ''
      );

      nixosModules.default = appModule;

      packages = eachSystem (system: {
        default = appFor.${system};
        backend = backendFor.${system};
        frontend = frontendFor.${system};
      });
    };
}
