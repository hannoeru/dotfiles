---
name: verify-dotfiles
description: Verify this dotfiles repository through its Nix, Home Manager, nix-darwin, and Pi command-line paths. Use after changes to the flake, machine definitions, modules, managed files, bootstrap flow, or Pi extensions, and before claiming that a dotfiles change works.
---

# Verify dotfiles

Drive this repository through the commands that a maintainer uses. Treat builds as build proof. Do not report activation proof unless you applied the configuration inside a disposable target and inspected the result.

Read [the feature map](features/README.md) before you choose a recipe.

## Launch

This project has no long-lived process. Start each run from the repository root in a new shell.

```sh
cd "$(git rev-parse --show-toplevel)"
export VERIFY_RUN_ID="${VERIFY_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
export VERIFY_ARTIFACT_DIR="$PWD/result/verify-dotfiles/$VERIFY_RUN_ID"
mkdir -p "$VERIFY_ARTIFACT_DIR"
printf '%s\n' "$VERIFY_RUN_ID" > "$VERIFY_ARTIFACT_DIR/run-id.txt"
git hash-object flake.lock > "$VERIFY_ARTIFACT_DIR/flake-lock.before.txt"
```

Use the existing Nix installation. Do not run `scripts/bootstrap.sh`, `home-manager switch`, `darwin-rebuild switch`, or an activation script on the current machine during verification.

There is no process teardown. Run the cleanup steps after each recipe.

## Doctor

Run this check before the first drive and after any unexpected result.

```sh
cd "$(git rev-parse --show-toplevel)"
test -n "${VERIFY_ARTIFACT_DIR:-}"
test -d "$VERIFY_ARTIFACT_DIR"
{
  printf 'root=%s\n' "$PWD"
  printf 'head=%s\n' "$(git rev-parse HEAD)"
  printf 'os=%s\n' "$(uname -s)"
  printf 'arch=%s\n' "$(uname -m)"
  nix --version
  printf 'pnpm=%s\n' "$(command -v pnpm || printf unavailable)"
  printf 'docker=%s\n' "$(command -v docker || printf unavailable)"
} | tee "$VERIFY_ARTIFACT_DIR/doctor.txt"
nix flake metadata --no-write-lock-file --json . > "$VERIFY_ARTIFACT_DIR/flake-metadata.json"
git hash-object flake.lock > "$VERIFY_ARTIFACT_DIR/flake-lock.after.txt"
cmp "$VERIFY_ARTIFACT_DIR/flake-lock.before.txt" "$VERIFY_ARTIFACT_DIR/flake-lock.after.txt"
```

A run is healthy when the root and commit are the intended checkout, Nix succeeds, flake metadata resolves, and Doctor does not change `flake.lock`. `pnpm` is required only for the Pi recipe. Docker is not required by the initial feature map.

## Drive

Use the recipe for the changed behavior.

- [Evaluate every configuration](features/evaluate-configurations.md).
- [Check Nix formatting](features/check-formatting.md).
- [Build a Linux home configuration](features/build-linux-home.md).
- [Build a macOS system configuration](features/build-macos-system.md).
- [Verify the Pi configuration](features/verify-pi.md).

Run one recipe at a time. Keep the command, standard output, standard error, and exit code in the recipe's evidence directory. Do not use fixed delays. Wait for each command to exit.

## Evidence

Store proof under `$VERIFY_ARTIFACT_DIR/<feature-id>/`. The repository ignores the top-level `result/` directory.

A complete proof contains:

- `command.txt` with the literal command.
- `output.log` with standard output and standard error.
- `exit-code.txt`.
- A read-only inspection of the produced store path when the recipe builds a configuration.
- `git-status.txt` after cleanup.

Exercise a documented maintainer command. Do not replace it with an internal Nix expression or a test-only path. A successful build proves that Nix produced an activation package or system closure. It does not prove that activation changed a machine correctly.

For an activation claim, use a disposable target. Capture the activation command and inspect the managed files, executable paths, shell, and configuration values from inside that target. If no disposable target exists, report activation as unreachable and name the missing target.

## Cleanup

Remove only scratch files created outside the evidence directory. Nix store paths can remain for garbage collection.

```sh
cd "$(git rev-parse --show-toplevel)"
rm -rf "$VERIFY_ARTIFACT_DIR/tmp"
git status --short > "$VERIFY_ARTIFACT_DIR/git-status.txt"
test -f "$VERIFY_ARTIFACT_DIR/doctor.txt"
test -f "$VERIFY_ARTIFACT_DIR/git-status.txt"
```

Do not delete `$VERIFY_ARTIFACT_DIR`. Never kill processes by name. The mapped recipes do not start background processes.

## Helpers

This skill uses the repository's existing commands. It does not add a wrapper script. `scripts/check.sh`, `nix fmt`, `nix build`, and the `home/.pi` package scripts remain the command sources.
