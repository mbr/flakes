{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    fenix = {
      url = "fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      fenix,
      flake-utils,
    }:
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

        platform = pkgs.makeRustPlatform {
          cargo = toolchain;
          rustc = toolchain;
        };

        cargoToml = pkgs.lib.importTOML ./Cargo.toml;

        # Fenix's lld doesn't set RPATH; use wrapped lld for native deps.
        rustEnv = {
          RUSTFLAGS = "-Clink-self-contained=-linker";
          OPENSSL_NO_VENDOR = "1";
        };
      in
      {
        packages.default = platform.buildRustPackage (
          rustEnv
          // rec {
            pname = cargoToml.package.name;
            version = cargoToml.package.version;
            description = cargoToml.package.description;
            nativeBuildInputs = with pkgs; [ llvmPackages.bintools ];

          src = pkgs.lib.cleanSource ./.;

          cargoLock = {
            lockFile = ./Cargo.lock;
          };

          meta.mainProgram = pname;
        });

        devShells.default = pkgs.mkShell (
          rustEnv
          // {
            inputsFrom = [ self.packages.${system}.default ];
            buildInputs = [ pkgs.nixfmt-rfc-style ];
          }
        );

        packages.docker = pkgs.dockerTools.buildImage {
          name = cargoToml.package.name;
          tag = cargoToml.package.version;

          config = {
            Cmd = [ (pkgs.lib.getExe self.packages.${system}.default) ];
          };
        };
      }
    );
}
