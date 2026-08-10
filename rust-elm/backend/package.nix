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
      ./Cargo.lock
      ./Cargo.toml
      ./src
    ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ llvmPackages.bintools ];

  inherit (rustEnv) RUSTFLAGS OPENSSL_NO_VENDOR;

  meta = {
    description = cargoToml.package.description;
    mainProgram = cargoToml.package.name;
  };
}
