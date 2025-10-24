{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pyproject = builtins.fromTOML (builtins.readFile ./pyproject.toml);

        pythonDeps =
          ps: with ps; [
            # Note: Python dependencies are managed by nix and should be
            #       added here instead of pyproject.toml.
            requests
          ];
      in
      {
        packages.default = pkgs.python3Packages.buildPythonApplication {
          pname = pyproject.project.name;
          version = pyproject.project.version;
          src = ./.;
          format = "pyproject";

          nativeBuildInputs = with pkgs.python3Packages; [
            setuptools
          ];

          propagatedBuildInputs = pythonDeps pkgs.python3Packages;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            (python3.withPackages pythonDeps)
            ruff
          ];
        };

        packages.docker = pkgs.dockerTools.buildImage {
          name = pyproject.project.name;
          tag = pyproject.project.version;

          config = {
            Cmd = [ "${self.packages.${system}.default}/bin/${pyproject.project.name}" ];
          };
        };
      }
    );
}
