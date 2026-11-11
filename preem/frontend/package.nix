{
  appName,
  elmPackages,
  esbuild,
  just,
  lib,
  nix,
  stdenvNoCC,
  tailwindcss_4,
}:

stdenvNoCC.mkDerivation {
  pname = "${appName}-frontend";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./css
      ./elm.json
      ./justfile
      ./public
      ./src
    ];
  };

  nativeBuildInputs = [
    elmPackages.elm
    esbuild
    just
    nix
    tailwindcss_4
  ];

  postConfigure = elmPackages.fetchElmDeps {
    elmPackages = import ./elm-srcs.nix;
    elmVersion = "0.19.1";
    registryDat = ./registry.dat;
  };

  buildPhase = ''
    runHook preBuild
    just build --release
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -R dist/. $out/
    runHook postInstall
  '';
}
