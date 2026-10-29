# dotfiles

Nix-managed dotfiles using [nix-darwin](https://github.com/nix-darwin/nix-darwin) and [home-manager](https://github.com/nix-community/home-manager).

## Machines

Defined once in `machines.nix`; the key is the flake configuration name.


| Configuration                      | Machine                                             |
| ---------------------------------- | --------------------------------------------------- |
| `darwinConfigurations.Han-MBP`     | Personal MacBook Pro                                |
| `darwinConfigurations.work`        | Work MacBook Pro                                    |
| `homeConfigurations.hanlee@ubuntu` | Personal Linux                                      |
| `homeConfigurations.ephemeral`    | Ephemeral machines (containers, devcontainers, WSL) |


Linux configurations also exist with an `-aarch64` suffix (e.g. `ephemeral-aarch64`) for ARM.

## Install

```
git clone https://github.com/hannoeru/dotfiles ~/dotfiles
~/dotfiles/scripts/bootstrap.sh
```

## Apply changes

macOS:

```
sudo darwin-rebuild switch --flake ~/dotfiles#Han-MBP
sudo darwin-rebuild switch --flake ~/dotfiles#work
```

Linux (x86_64):

```
nix run ~/dotfiles#home-manager -- switch -b backup --flake ~/dotfiles#ephemeral
```

Linux (aarch64):

```
nix run ~/dotfiles#home-manager -- switch -b backup --flake ~/dotfiles#ephemeral-aarch64
```

Update inputs:

```
nix flake update
```

## Containers on macOS

Nix installs Colima and Docker on both Mac configurations. The Docker package
includes the `docker compose` and `docker buildx` plugins. Linux keeps its existing
Docker package without the Colima service.

Home Manager starts Colima at login. Colima runs Docker in a Linux virtual machine
with Apple's Virtualization framework and VirtioFS file sharing. The first start
needs network access to download the virtual machine image. Colima selects the
`colima` Docker context when it starts.

After you apply the macOS configuration, inspect the service and Docker plugins:

```sh
colima status
docker context show
docker info
docker compose version
docker buildx version
docker run --rm hello-world
```

To start Colima before the next login, run `colima start`. Service logs are in
`~/.local/state/colima/default.log`. Nix does not install OrbStack or load its shell
integration. An existing OrbStack installation and its data remain unchanged.
Stop OrbStack before you start Colima to avoid competing Docker contexts.

## Development

```
nix fmt                    # format Nix files
nix run .#darwin-rebuild   # pinned darwin-rebuild
scripts/check.sh           # eval-only check of all flake outputs
```

A scheduled workflow opens a pull request every Monday to update `flake.lock`.
Because that pull request is opened with the default workflow token, GitHub
does not run the `check` workflow on it; the check runs after the merge.

See [Managed skills](docs/skills.md).

## Dev container

`containers/devcontainer/Dockerfile` builds a base image (Ubuntu + Nix + this
repo's `ephemeral` configuration) and CI publishes it to
`ghcr.io/hannoeru/devcontainer` for amd64 and arm64. `.devcontainer/devcontainer.json` uses
that image, so any repository can adopt the same environment by referencing
it. mise runtimes are not pre-installed in the image; mise installs each one
on first use.

## Layout

- `machines.nix` — all machine definitions (single source of truth)
- `modules/darwin.nix` — shared nix-darwin system config
- `modules/home/` — shared home-manager config (`programs/` holds one module per program)
- `home/` — dotfiles applied verbatim to `$HOME`
- `containers/devcontainer/` — devcontainer base image
- `scripts/bootstrap.sh` — fresh machine bootstrap

## Notes

- GUI apps and fonts come from Homebrew (managed by nix-darwin); manually installed packages are left alone.
- Language runtimes (node, python, ...) come from [mise](https://mise.jdx.dev); run `mise install` after first activation (bootstrap does this), or rely on mise's auto-install on first use (the devcontainer does).
- direnv with nix-direnv is enabled in Bash and Zsh. The whitelist uses the absolute home path with a `/projects/` suffix to automatically approve `.envrc` files under `~/projects`, including cloned repositories. The trailing slash excludes names such as `~/projects-other`. Files elsewhere are blocked unless explicitly approved with `direnv allow`; the whitelist is not a strict path restriction.
- Personal Homebrew apps, including 1Password and its CLI, follow `personal` in `machines.nix`.
- `onePassword` in `machines.nix` defaults to `true` and controls the SSH agent config, Git signing include, and secret lookups, not app installation. The work Mac sets it to `false`. When enabled, personal secrets (git signing key, SSH config) come from the [1Password CLI](https://developer.1password.com/docs/cli/) during activation; if it is missing, they are skipped. Run the switch a second time after installing it.
- Clean the Nix store occasionally: `nix-collect-garbage --delete-older-than 30d`.

