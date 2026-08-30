#!/bin/sh

# Eval-only check: verifies that all flake outputs (every system,
# configuration, and package) evaluate without building anything.

set -eu

script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"
flake_dir="$(cd -P "$script_dir/.." && pwd -P)"

cd "$flake_dir"
nix flake check --all-systems --no-build