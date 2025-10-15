# flake templates

A repository with flake(s) to create new nix-enabled projects with minimal fuss.

Usage:

```
nix flake init -t github:mbr/flakes#rust
```

The `#rust` part is optional, as it is the default. If you are using bash, you may have to quote or escape the `#`.

## Available templates

* `rust`: Builds a Rust project using the [fenix](https://github.com/nix-community/fenix) overlay.

## Alternatives

For official Nix flake templates, see the [NixOS/templates](https://github.com/NixOS/templates) repository.
