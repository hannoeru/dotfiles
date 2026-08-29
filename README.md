# dotfiles

Nix-managed dotfiles using [nix-darwin](https://github.com/nix-darwin/nix-darwin) and [home-manager](https://github.com/nix-community/home-manager).

## Machines

Defined once in `machines.nix`; the key is the flake configuration name.

| Configuration | Machine |
| --- | --- |
| `darwinConfigurations.Han-MBP` | Personal MacBook Pro |
| `darwinConfigurations.work` | Work MacBook |
| `homeConfigurations.hanlee@ubuntu` | Personal Linux box |
| `homeConfigurations.hanlee` | Ephemeral machines (containers, devcontainers, WSL) |

Linux configurations also exist with an `-aarch64` suffix (e.g. `hanlee-aarch64`) for ARM.

## Install

    git clone https://github.com/hannoeru/dotfiles ~/dotfiles
    ~/dotfiles/scripts/bootstrap.sh

## Apply changes

macOS:

    sudo darwin-rebuild switch --flake ~/dotfiles#Han-MBP
    sudo darwin-rebuild switch --flake ~/dotfiles#work

Linux:

    home-manager switch --flake ~/dotfiles#hanlee

Update inputs:

    nix flake update

## Development

    nix fmt                    # format Nix files
    nix run .#darwin-rebuild   # pinned darwin-rebuild

## Layout

- `machines.nix` — all machine definitions (single source of truth)
- `modules/darwin.nix` — shared nix-darwin system config
- `modules/home/` — shared home-manager config (`programs/` holds one module per program)
- `files/` — dotfiles applied verbatim to `$HOME`
- `scripts/bootstrap.sh` — fresh machine bootstrap

## Notes

- GUI apps and fonts come from Homebrew (managed by nix-darwin); manually installed packages are left alone.
- Language runtimes (node, python, ...) come from [mise](https://mise.jdx.dev); run `mise install` after first activation (bootstrap does this).
- Personal secrets (git signing key, SSH config) come from the [1Password CLI](https://developer.1password.com/docs/cli/) during activation; if it is missing, they are skipped. Run the switch a second time after installing it.
- Clean the Nix store occasionally: `nix-collect-garbage --delete-older-than 30d`.
