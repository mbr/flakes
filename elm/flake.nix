{
  description = "Elm application";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        elmApp = pkgs.stdenv.mkDerivation {
          pname = "myapp";
          version = "0.1.0";

          src = ./.;

          nativeBuildInputs = with pkgs; [
            elmPackages.elm
            nodePackages.tailwindcss
          ];

          configurePhase =
            let
              elmConfigure = pkgs.elmPackages.fetchElmDeps {
                elmPackages = import ./elm-srcs.nix;
                elmVersion = "0.19.1";
                registryDat = ./registry.dat;
              };
            in
            ''
              ${elmConfigure}
            '';

          buildPhase = ''
            ./build.sh --release
          '';

          installPhase = ''
            mkdir -p $out
            cp index.html main.js style.css $out/
          '';
        };
      in
      {
        packages = {
          default = elmApp;
        };

        devShells = {
          default = pkgs.mkShell {
            inputsFrom = [ elmApp ];
            buildInputs = with pkgs; [
              elmPackages.elm-format
              elmPackages.elm-test
              elmPackages.elm-review
              elm2nix
            ];
          };
        };
      });
}
