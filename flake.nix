# Flake template from: https://github.com/mbr/flakes

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
          * (potentially) Change the pinned NixOS version, also in `flake.nix`.

          ## Development

          `nix develop` to enter a dev shell

          ## Building the derivation

          * `nix build` to build the derivation, `result/bin/..` will contain your binary
          * Alternative `nix build '#docker'` will build a docker image (load it with `podman/docker load -i result`)
        '';
      };

      templates.default = self.templates.rust;
    };
}
