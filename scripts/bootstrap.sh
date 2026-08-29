#!/bin/sh

# Bootstrap a machine from a fresh install:
# 1. install Nix (and Homebrew on macOS) if missing
# 2. apply the system configuration
# 3. install language runtimes with mise

set -eu

script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"
flake_dir="$(cd -P "$script_dir/.." && pwd -P)"

if ! command -v nix >/dev/null 2>&1; then
  echo "==> Installing Nix"
  curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix/tag/v3.22.2/nix-installer.sh \
    | sh -s -- install
fi

# The installer cannot modify this shell's environment; add the Nix
# profile paths so the commands below can run.
export PATH="/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin:$PATH"

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
    case "$hostname" in
      Han-MBP) darwin_config="Han-MBP" ;;
      *) darwin_config="work" ;;
    esac
    # Build as the user, activate as root (same script darwin-rebuild runs).
    toplevel="$(nix build --no-link --print-out-paths \
      "$flake_dir#darwinConfigurations.$darwin_config.system")"
    sudo "$toplevel/activate"
    ;;

  Linux)
    host="$(hostname -s)"
    case "$host" in
      ubuntu) home_config="hanlee@ubuntu" ;;
      *) home_config="hanlee" ;;
    esac
    case "$(uname -m)" in
      x86_64) ;;
      aarch64 | arm64) home_config="$home_config-aarch64" ;;
      *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
    esac
    nix run "$flake_dir#home-manager" -- switch -b backup --flake "$flake_dir#$home_config"

    # zsh comes from home-manager; chsh needs the path in /etc/shells.
    zsh="$(command -v zsh || true)"
    if [ -n "$zsh" ] && [ "$SHELL" != "$zsh" ]; then
      echo "==> Setting login shell to zsh"
      if ! grep -qx "$zsh" /etc/shells 2>/dev/null; then
        if [ "$(id -u)" -eq 0 ]; then
          echo "$zsh" >> /etc/shells
        elif command -v sudo >/dev/null 2>&1; then
          echo "$zsh" | sudo tee -a /etc/shells >/dev/null
        else
          echo "warning: cannot add $zsh to /etc/shells" >&2
        fi
      fi
      chsh -s "$zsh" || echo "warning: could not change login shell" >&2
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
else
  echo "warning: mise not on PATH yet; run 'mise install' in a new shell" >&2
fi
