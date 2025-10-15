{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
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
          "rust-src"
          "rustc"
          "rustfmt"
        ];

        platform = pkgs.makeRustPlatform {
          cargo = toolchain;
          rustc = toolchain;
        };

        cargoToml = pkgs.lib.importTOML ./Cargo.toml;
      in
      {
        packages.default = platform.buildRustPackage rec {
          pname = cargoToml.package.name;
          version = cargoToml.package.version;
          description = cargoToml.package.description;
          nativeBuildInputs = with pkgs; [ ];

          src = pkgs.lib.cleanSource ./.;

          cargoLock = {
            lockFile = ./Cargo.lock;
          };
        };

        packages.docker = pkgs.dockerTools.buildImage {
          name = cargoToml.package.name;
          tag = cargoToml.package.version;

          config = {
            Cmd = [ "${self.packages.${system}.default}/bin/${cargoToml.package.name}" ];
          };
        };
      }
    );
}
