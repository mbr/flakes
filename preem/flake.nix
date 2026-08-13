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
        moduleTest =
          serviceConfig:
          nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              appModule
              {
                services.myapp = {
                  enable = true;
                }
                // serviceConfig;
                system.stateVersion = "26.05";
              }
            ];
          };
      in
      {
        checks =
          let
            tcpModule = moduleTest {
              listenAddress = "[::1]:3000";
              openFirewall = true;
            };
            unixModule = moduleTest {
              listenAddress = "/run/myapp/http.sock";
            };
            directModule = moduleTest {
              listenAddress = "/run/myapp/http.sock";
              socketActivation = false;
            };
            caddyModule = moduleTest {
              listenAddress = "/run/myapp/http.sock";
              caddy = {
                enable = true;
                virtualHost = "app.example.com";
              };
            };
            socketActivationTest = pkgs.testers.runNixOSTest (import ./nixos-test.nix { inherit appModule; });
          in
          {
            default = app;
            inherit backend frontend;
          }
          // pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
            nixos-module =
              assert builtins.elem 3000 tcpModule.config.networking.firewall.allowedTCPPorts;
              assert tcpModule.config.systemd.services.myapp.serviceConfig.Type == "notify";
              assert tcpModule.config.systemd.services.myapp.serviceConfig.TimeoutStartSec == 60;
              assert tcpModule.config.systemd.services.myapp.serviceConfig.TimeoutStopSec == 30;
              assert tcpModule.config.systemd.services.myapp.serviceConfig.RestartSec == "10s";
              assert tcpModule.config.systemd.services.myapp.startLimitIntervalSec == 0;
              assert tcpModule.config.systemd.sockets.myapp.listenStreams == [ "[::1]:3000" ];
              tcpModule.config.systemd.units."myapp.service".unit;
            nixos-module-unix =
              assert unixModule.config.systemd.services.myapp.serviceConfig.Group == "myapp";
              assert unixModule.config.systemd.sockets.myapp.socketConfig.SocketGroup == "myapp-proxy";
              assert unixModule.config.systemd.sockets.myapp.socketConfig.SocketMode == "0660";
              assert unixModule.config.systemd.tmpfiles.settings."10-myapp"."/run/myapp".d.group == "myapp-proxy";
              unixModule.config.systemd.units."myapp.socket".unit;
            nixos-module-direct =
              assert !(directModule.config.systemd.sockets ? myapp);
              assert directModule.config.systemd.services.myapp.serviceConfig.Group == "myapp-proxy";
              assert directModule.config.systemd.services.myapp.serviceConfig.RuntimeDirectory == "myapp";
              directModule.config.systemd.units."myapp.service".unit;
            nixos-module-integration = socketActivationTest;
            nixos-module-caddy =
              assert caddyModule.config.services.caddy.enable;
              assert
                caddyModule.config.services.caddy.virtualHosts."app.example.com".extraConfig == ''
                  reverse_proxy unix//run/myapp/http.sock
                '';
              assert builtins.elem "myapp-proxy"
                caddyModule.config.systemd.services.caddy.serviceConfig.SupplementaryGroups;
              caddyModule.config.systemd.units."caddy.service".unit;
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
