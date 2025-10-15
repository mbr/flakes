{
  description = "A collection of flake templates";

  outputs =
    { self }:
    {

      templates.rust = {
        path = ./rust;
        description = "A simple Rust/Cargo project";
        welcomeText = ''
          # Simple Rust/Cargo Template
          ## Intended usage
          The intended usage of this flake is...

          ## More info
          - [Rust language](https://www.rust-lang.org/)
          - [Rust on the NixOS Wiki](https://wiki.nixos.org/wiki/Rust)
          - ...
        '';
      };

      templates.default = self.templates.rust;
    };
}
