"""Configure the API documentation build."""

from pathlib import Path
import tomllib

with (Path(__file__).resolve().parents[1] / "pyproject.toml").open("rb") as metadata:
    pyproject = tomllib.load(metadata)["project"]

project = pyproject["name"]
release = pyproject["version"]

extensions = ["myst_parser", "sphinx.ext.autodoc"]
exclude_patterns = ["_build"]
html_theme = "furo"
