{
  description = "PREEM full-stack web application";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    fenix = {
      url = "fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pgdb = {
      url = "github:mbr/pgdb-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      fenix,
      pgdb,
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
        SQLX_OFFLINE = "true";
      });
      sqlxCliFor = eachSystem (
        system:
        let
          sqlxDependency = (pkgsFor.${system}.lib.importTOML ./backend/Cargo.toml).dependencies.sqlx;
          sqlxVersion = pkgsFor.${system}.lib.removePrefix "=" sqlxDependency.version;
        in
        assert pkgsFor.${system}.sqlx-cli.version == sqlxVersion;
        pkgsFor.${system}.sqlx-cli
      );
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
          postBuild = ''
            mkdir -p $out/share/${name}
            ln -s ${frontend} $out/share/${name}/frontend
          '';
          meta = backend.meta // {
            mainProgram = name;
          };
        }
      );
      appModule = import ./nixos-module.nix { inherit self; };
      moduleTestFor =
        system: serviceConfig:
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
      checks = eachSystem (
        system:
        let
          tcpModule = moduleTestFor system {
            listenAddress = "[::1]:3000";
            openFirewall = true;
          };
          unixModule = moduleTestFor system {
            listenAddress = "/run/myapp/http.sock";
          };
          directModule = moduleTestFor system {
            listenAddress = "/run/myapp/http.sock";
            socketActivation = false;
          };
          caddyModule = moduleTestFor system {
            listenAddress = "/run/myapp/http.sock";
            caddy = {
              enable = true;
              virtualHost = "app.example.com";
            };
          };
          socketActivationTest = pkgsFor.${system}.testers.runNixOSTest {
            name = "myapp-socket-activation";
            nodes.machine = { pkgs, ... }: {
              imports = [ appModule ];
              services.myapp = {
                enable = true;
                listenAddress = "/run/myapp/http.sock";
              };
              environment.systemPackages = [ pkgs.curl ];
              system.stateVersion = "26.05";
            };
            testScript = ''
              start_all()
              machine.wait_for_unit("myapp.socket")
              machine.wait_for_unit("myapp.service")
              machine.wait_until_succeeds(
                  "curl --fail --silent --unix-socket /run/myapp/http.sock http://localhost/api/status"
              )
              machine.succeed("test $(stat --format=%a /run/myapp/http.sock) = 660")
              machine.succeed("test $(stat --format=%G /run/myapp/http.sock) = myapp-proxy")

              socket_inode = machine.succeed("stat --format=%i /run/myapp/http.sock").strip()
              machine.succeed("systemctl restart myapp.service")
              machine.wait_for_unit("myapp.service")
              assert machine.succeed("stat --format=%i /run/myapp/http.sock").strip() == socket_inode
              machine.succeed(
                  "curl --fail --silent --unix-socket /run/myapp/http.sock http://localhost/api/status"
              )
            '';
          };
        in
        {
          default = appFor.${system};
          backend = backendFor.${system};
          frontend = frontendFor.${system};
        }
        // nixpkgs.lib.optionalAttrs pkgsFor.${system}.stdenv.isLinux {
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
              esbuild
              nixfmt
              pgdb.packages.${system}.default
              postgresql
              python3Packages.ephemeral-port-reserve
              process-compose
              sqlxCliFor.${system}
              tailwindcss_4
              toolchainFor.${system}
            ];
          }
        );
      });

      formatter = eachSystem (
        system:
        pkgsFor.${system}.writeShellScriptBin "preem-format" ''
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
