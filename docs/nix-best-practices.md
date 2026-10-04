# Nix best-practices review

This review covers `flake.nix`, `flake.lock`, `machines.nix`, `modules/darwin.nix`, `modules/home/**`, the bootstrap and check scripts, and the Nix-related GitHub Actions workflows.

## Summary

The repository has a sound base. It pins inputs, shares one Nixpkgs input, uses the supported nix-darwin and Home Manager module interfaces, and declares platforms explicitly. This review found a broken plain `nix fmt` command, an unavailable Linux apply command in the README, custom Home Manager activation code that performed some work during dry runs, and missing AArch64 Linux build coverage in CI. The formatter, Linux apply command, and dry-run behavior are now fixed.

## Established guidance

### Keep the current input and lock-file model

Keep `flake.lock` in version control and continue updating it through the scheduled pull request. A flake lock file pins direct and transitive inputs, while `nix flake update` updates the selected lock entries. The current `nix-darwin.inputs.nixpkgs.follows` and `home-manager.inputs.nixpkgs.follows` settings correctly make both modules use the repository's selected Nixpkgs input. [Nix flake reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake.html) · [Nix input update reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-update.html) · [nix.dev flake guidance](https://nix.dev/concepts/flakes.html)

Keep Home Manager on its rolling branch while this repository uses `nixpkgs-unstable`. Home Manager recommends matching its release with Nixpkgs, and its release check is enabled by default. [Home Manager `home.enableNixpkgsReleaseCheck`](https://home-manager.dev/manual/unstable/options/home-manager/home.html)

### Preserve both state versions

Do not raise `home.stateVersion = "25.05"` merely because Home Manager is updated. It selects compatibility behavior, and changing it can require manual data or file migrations. [Home Manager configuration guidance](https://home-manager.dev/manual/unstable/usage/configuration.html) · [Home Manager option reference](https://home-manager.dev/manual/unstable/options/home-manager/home.html)

Apply the same rule to `system.stateVersion = 7`. Review nix-darwin's changelog before changing it. The upstream example identifies this value as the compatibility baseline rather than the installed nix-darwin version. [nix-darwin example configuration](https://github.com/nix-darwin/nix-darwin/blob/master/modules/examples/simple.nix) · [nix-darwin changelog](https://github.com/nix-darwin/nix-darwin/blob/master/CHANGELOG)

### Keep the current nix-darwin platform and Nix ownership settings

`nixpkgs.hostPlatform = "aarch64-darwin"` is the preferred option for the target platform. Keep it while every declared Mac is Apple Silicon. [nix-darwin option manual](https://nix-darwin.github.io/nix-darwin/manual/) · [nix-darwin flake example](https://github.com/nix-darwin/nix-darwin/blob/master/README.md)

Keep `nix.enable = false` while the Determinate installation owns Nix and its daemon. This setting tells nix-darwin not to manage Nix, `nix-daemon`, or `/etc/nix/nix.conf`; it also means nix-darwin's `nix.*` settings are unavailable. [nix-darwin `nix.enable` option](https://nix-darwin.github.io/nix-darwin/manual/)

### Keep the Home Manager integration pattern

The repository correctly imports `home-manager.darwinModules.home-manager`, defines the user under `home-manager.users`, and passes repository-specific module arguments through `extraSpecialArgs`. [Home Manager nix-darwin installation](https://home-manager.dev/manual/unstable/installation/nix-darwin.html) · [Home Manager nix-darwin options](https://home-manager.dev/manual/unstable/options/nix-darwin/home-manager.html)

Keep `useGlobalPkgs = true`. Home Manager documents that this reuses nix-darwin's `pkgs`, avoids a second Nixpkgs evaluation, and keeps package policy consistent. Keep `useUserPackages = true` if `/etc/profiles/per-user/$USER` is the intended package profile. [Home Manager nix-darwin installation](https://home-manager.dev/manual/unstable/installation/nix-darwin.html)

### Keep the eval-only check

Keep `scripts/check.sh` as the fast evaluation check. Local verification with Determinate Nix 3.22.2 and Nix 2.35.2 showed that `nix flake check --all-systems --no-build` evaluated all four `homeConfigurations` and both `darwinConfigurations`, then reported each as a build-skipped success. Its eval-only description is accurate. `--all-systems` checks every system, while `--no-build` skips building derivations. Keep the explicit Linux and macOS builds in `.github/workflows/check.yml` for build coverage. [Nix `flake check` reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-check.html)

### Home Manager dry-run behavior

Custom activation entries remain after `linkGeneration`; Home Manager defines `linkGeneration` after `writeBoundary`, the point after which persistent changes are allowed. Activation entries must be idempotent and must report rather than perform changes during a dry run. [Home Manager activation option](https://home-manager.dev/manual/unstable/options/home-manager/home.html) · [Home Manager file activation source](https://github.com/nix-community/home-manager/blob/master/modules/files.nix)

`signingKey` and `personalSshConfig` now guard their complete mutating branches with Home Manager's `DRY_RUN` flag. A dry run reports each target without calling 1Password, creating temporary files, or writing configuration. The `piNodeModules` and `linkWorktrunkPlugin` mutations continue to use `DRY_RUN_CMD`. [Home Manager activation option](https://home-manager.dev/manual/unstable/options/home-manager/home.html)

### Flake formatter

The formatter now uses `nixfmt-tree`. Before this change, plain `nix fmt` invoked bare `nixfmt` without file arguments, so it read empty standard input and failed. CI passed only because it supplied an explicit file list.

`nix fmt` now formats the repository, and CI uses `nix fmt -- --ci` to fail if formatting changes a file. `nix fmt` runs `formatter.<system>`, and the current Nix reference and official nixfmt README use `nixfmt-tree` for project-wide flake formatting. [Nix `fmt` reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-fmt.html) · [official nixfmt README](https://github.com/NixOS/nixfmt/blob/master/README.md)

### Linux apply command

The README now uses the flake's Home Manager app:

```sh
nix run ~/dotfiles#home-manager -- switch -b backup --flake ~/dotfiles#ephemeral
```

The README also gives the `ephemeral-aarch64` command for AArch64 Linux. The previous command assumed that `home-manager` was on `PATH`, but the standalone configurations leave `programs.home-manager.enable` disabled and do not add the Home Manager package to `home.packages`. Using the flake app and backup extension also matches the bootstrap script. Another valid choice is to enable `programs.home-manager.enable`, which installs the Home Manager command and lets Home Manager manage its own installation. [Home Manager `programs.home-manager.enable` option](https://home-manager.dev/manual/unstable/options/home-manager/home.html)

### Keep source files tracked

Add new Nix modules and dotfiles to Git before evaluating the flake. For a local Git flake, Nix copies tracked files into the source tree and does not see an untracked file. [Nix flake reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake.html) · [nix.dev flake guidance](https://nix.dev/concepts/flakes.html)

## Judgment calls

These changes are not required by the module interfaces. They are repository policy choices.

1. **Add first-class build checks.** The eval-only script covers all six configurations. CI builds both Macs and the two x86_64 Linux activation packages, but it does not build the two aarch64 Linux activation packages. I would expose configuration derivations as checks only if the repository should use `nix flake check` as its common build-test interface. The standard output and build behavior come from the [Nix `flake check` reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-check.html).

2. **Disable Homebrew auto-update during ordinary activation.** I would set `homebrew.onActivation.autoUpdate = false` and update Homebrew on a separate schedule. This reduces network-dependent changes during `darwin-rebuild`; nix-darwin documents that `autoUpdate` runs `brew update` before `brew bundle`. [nix-darwin Homebrew options](https://nix-darwin.github.io/nix-darwin/manual/)

3. **Choose an explicit backup policy.** `backupFileExtension = "backup"` preserves an unmanaged target, but activation fails if that backup already exists unless `overwriteBackup` is enabled. Keeping the safe failure is reasonable. A timestamped `backupCommand` is better if repeated collisions are expected. [Home Manager nix-darwin backup options](https://home-manager.dev/manual/unstable/options/nix-darwin/home-manager.html)

4. **Centralize supported systems only when another output needs them.** The repeated platform lists in `apps` and `formatter` are small and readable now. A shared list becomes useful only if `checks`, packages, or development shells add another consumer. Nix requires system-specific outputs to name their platforms explicitly. [nix.dev flake guidance](https://nix.dev/concepts/flakes.html)
