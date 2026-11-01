# Python library

A Python library built and tested with Nix.

## Setup

Rename `myproject/` and update `pyproject.toml`, `pythonImportsCheck` in
`flake.nix`, the tests, and `docs/index.md`. Set the project description and
supported Python versions, and add author and license metadata before publishing.
Restore the publishing script's permissions with `chmod +x publish.sh` if needed.

Run `direnv allow` or `nix develop` to enter the development environment.
The `.envrc` loads optional credentials from the ignored `.env` file.

## Development

- `pytest` runs the tests.
- `nix fmt` formats and lints the project.
- `nix build` builds the library and documentation and runs tests and import checks.
- `nix build '.#default^doc' -o result-doc` exposes the documentation output.
- `nix flake check -L` checks formatting and builds the library, as CI does.

## Publishing

From the development environment, run `./publish.sh` to check the project, build
an sdist and wheel, validate their metadata, and upload them with Twine. Configure
Twine credentials and the target repository before running it; it defaults to PyPI.
