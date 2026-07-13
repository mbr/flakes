{
  description = "Elm application";

  inputs.nixpkgs.url = "nixpkgs/nixos-26.05";

  outputs =
    inputs:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      eachSystem = inputs.nixpkgs.lib.genAttrs systems;
      pkgsFor = eachSystem (system: inputs.nixpkgs.legacyPackages.${system});
      elmAppFor = eachSystem (
        system:
        let
          pkgs = pkgsFor.${system};
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "myapp";
          version = "0.1.0";

          src = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./build.sh
              ./css
              ./elm.json
              ./public
              ./src
            ];
          };

          nativeBuildInputs = [
            pkgs.elmPackages.elm
            pkgs.tailwindcss_4
          ];

          postConfigure = pkgs.elmPackages.fetchElmDeps {
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
      );
    in
    {
      checks = eachSystem (system: {
        default = elmAppFor.${system};
      });

      devShells = eachSystem (system: {
        default = pkgsFor.${system}.mkShell {
          inputsFrom = [ elmAppFor.${system} ];
          packages = with pkgsFor.${system}; [
            elm2nix
            elmPackages.elm-format
            nixfmt
            python3
            watchexec
          ];
        };
      });

      formatter = eachSystem (
        system:
        pkgsFor.${system}.writeShellScriptBin "elm-project-format" ''
          set -eu
          ${pkgsFor.${system}.elmPackages.elm-format}/bin/elm-format --yes src
          ${pkgsFor.${system}.nixfmt}/bin/nixfmt flake.nix elm-srcs.nix
        ''
      );

      packages = eachSystem (system: {
        default = elmAppFor.${system};
      });
    };
}
