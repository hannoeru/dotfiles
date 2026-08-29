#!/bin/sh

# Bootstrap a machine from a fresh install:
# 1. install Nix (and Homebrew on macOS) if missing
# 2. apply the system configuration
# 3. install language runtimes with mise

set -eu

script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"

if ! command -v nix >/dev/null 2>&1; then
  echo "==> Installing Nix"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
fi

# flakes are enabled persistently by the darwin configuration;
# this makes the first run work before that has been applied
export NIX_CONFIG="extra-experimental-features = nix-command flakes"

case "$(uname)" in
  Darwin)
    if ! command -v brew >/dev/null 2>&1; then
      echo "==> Installing Homebrew"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    hostname="$(scutil --get LocalHostName)"
    nix run nix-darwin -- switch --flake "$script_dir#$hostname"
    ;;

  Linux)
    case "$(uname -m)" in
      x86_64) home_config="hanlee" ;;
      aarch64 | arm64) home_config="hanlee-aarch64" ;;
      *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
    esac
    nix run home-manager -- switch -b backup --flake "$script_dir#$home_config"
    zsh="$(command -v zsh || true)"
    if [ -n "$zsh" ] && [ "$SHELL" != "$zsh" ]; then
      echo "==> Setting login shell to zsh"
      chsh -s "$zsh"
    fi
    ;;

  *)
    echo "Unsupported OS: $(uname)" >&2
    exit 1
    ;;
esac

if command -v mise >/dev/null 2>&1; then
  echo "==> Installing language runtimes"
  mise install
fi
