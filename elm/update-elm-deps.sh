#!/bin/sh

#: Update nix Elm depedencies from Elm lockfile.

set -e

elm2nix convert > elm-srcs.nix
elm2nix snapshot
