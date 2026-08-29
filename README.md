# github.com/hannoeru/dotfiles

Hannoeru's dotfiles, managed with [Nix](https://nixos.org) ([nix-darwin](https://github.com/nix-darwin/nix-darwin) + [home-manager](https://github.com/nix-community/home-manager)).

## Machines

Defined once in `machines.nix`; the key is the flake configuration name.

| Configuration | Machine |
| --- | --- |
| `darwinConfigurations.Han-MBP` | Personal MacBook Pro |
| `darwinConfigurations.work` | Work MacBook |
| `homeConfigurations.hanlee@ubuntu` | Personal headless Linux box (x86_64) |
| `homeConfigurations.hanlee` | Ephemeral machines (containers, devcontainers, WSL), x86_64 |

The darwin configurations assume Apple Silicon; change `nixpkgs.hostPlatform`
in `modules/darwin.nix` to `x86_64-darwin` for an Intel Mac. Every Linux
configuration also exists with an `-aarch64` suffix (e.g. `homeConfigurations.hanlee-aarch64`)
for ARM machines such as containers running on Apple Silicon.

CLI tools come from nixpkgs. GUI apps and fonts are installed through
[Homebrew](https://brew.sh) (managed by nix-darwin's `homebrew` module) with
`cleanup = "none"`: packages installed manually are left alone. A few
clearly personal casks (Google Drive, Keka, Spotify) are only installed on
personal machines. VS Code extensions are not managed — install them
manually. Language runtimes (node, python, ...) are managed with
[mise](https://mise.jdx.dev); `mise use --global` stays available because
home-manager keeps the main `config.toml` mutable.

Personal secrets are stored in [1Password](https://1password.com) and you'll
need the [1Password CLI](https://developer.1password.com/docs/cli/) installed.
The git signing key and personal SSH config are fetched from 1Password during
activation; without the CLI they are skipped with a warning. On the first
bootstrap the CLI may not be installed yet when home-manager activates —
run the switch a second time to pick up the secrets.

Ephemeral Linux configurations assume the user is `hanlee`; a container
running as a different user needs its own entry in `machines.nix`.

## Install

Bootstrap a fresh machine (installs Nix, Homebrew on macOS, and applies
everything):

    git clone https://github.com/hannoeru/dotfiles ~/dotfiles
    ~/dotfiles/scripts/bootstrap.sh

## Apply changes

macOS (as root; personal Mac uses its host name as the configuration
name, the work Mac uses `work`):

    sudo darwin-rebuild switch --flake ~/dotfiles#Han-MBP
    sudo darwin-rebuild switch --flake ~/dotfiles#work

Linux (pass `-b backup` on the first switch to move conflicting leftover
files aside):

    home-manager switch --flake ~/dotfiles#hanlee

Update inputs (nixpkgs, nanorc, ...):

    nix flake update

## Development

    nix fmt                # format Nix files
    nix run .#darwin-rebuild   # pinned darwin-rebuild from the lockfile

CI builds both Linux home configurations on Linux and both darwin
configurations on macOS runners.

## Layout

- `machines.nix` — all machine definitions (single source of truth)
- `modules/darwin.nix` — shared nix-darwin system configuration (defaults, Homebrew, GC)
- `modules/home/` — shared home-manager configuration (`default.nix` plus one module per program in `programs/`)
- `files/` — dotfiles without home-manager modules, applied verbatim to `$HOME`
- `scripts/bootstrap.sh` — fresh machine bootstrap

## Notes

- mise runtimes: run `mise install` after the first activation
  (bootstrap does this for you).
- pi agent dependencies: run `pnpm install` in `~/.pi` after mise provides
  node and pnpm.
- Nix garbage collection runs weekly on macOS and removes store paths older
  than 30 days.
