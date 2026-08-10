{
  elmPackages,
  lib,
  stdenvNoCC,
  tailwindcss_4,
}:

stdenvNoCC.mkDerivation {
  pname = "myapp-frontend";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./build.sh
      ./css
      ./elm.json
      ./public
      ./src
    ];
  };

  nativeBuildInputs = [
    elmPackages.elm
    tailwindcss_4
  ];

  postConfigure = elmPackages.fetchElmDeps {
    elmPackages = import ./elm-srcs.nix;
    elmVersion = "0.19.1";
    registryDat = ./registry.dat;
  };

  buildPhase = ''
    runHook preBuild
    ./build.sh --release
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -R dist/. $out/
    runHook postInstall
  '';
}
