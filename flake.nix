{
  description = "A collection of flake templates";

  outputs =
    { self }:
    {
      templates.rust = {
        path = ./rust;
        description = "A Rust project";
        welcomeText = ''
          # Rust project

          Uses Fenix to provide Rust, self-contained flake.

          ## Next steps (recommended)

          * Edit `Cargo.toml`
          * Add native build dependencies to `flake.nix` (if any)

          ## Development

          `nix develop` to enter a dev shell

          ## Building a derivation

          `nix build` to build a derivation. `result/bin/..` will contain your binary
        '';
      };

      templates.default = self.templates.rust;
    };
}
