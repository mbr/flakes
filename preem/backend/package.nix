{
  lib,
  llvmPackages,
  rustEnv,
  rustPlatform,
}:

let
  cargoToml = lib.importTOML ./Cargo.toml;
in
rustPlatform.buildRustPackage {
  pname = cargoToml.package.name;
  version = cargoToml.package.version;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./.sqlx
      ./Cargo.lock
      ./Cargo.toml
      ./migrations
      ./src
    ];
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes."twelve-0.3.0" = "sha256-Wsrr3N1QJzj2A4U4mnG9R3BMwg59DUrtG44YJyr7hAw=";
  };

  nativeBuildInputs = [ llvmPackages.bintools ];

  inherit (rustEnv) RUSTFLAGS OPENSSL_NO_VENDOR SQLX_OFFLINE;

  meta = {
    description = cargoToml.package.description;
    mainProgram = cargoToml.package.name;
  };
}
