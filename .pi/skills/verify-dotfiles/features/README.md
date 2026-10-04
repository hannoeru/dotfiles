# Dotfiles verification map

This directory is the maintained source for verifying the user-facing behavior of the dotfiles repository. Read this index before you run a recipe.

## Baseline preconditions

- Run from the intended Git checkout.
- Use a working Nix installation with flakes enabled.
- Set `VERIFY_RUN_ID` and `VERIFY_ARTIFACT_DIR` through the skill's Launch section.
- Run the skill's Doctor section.
- Keep the current machine unchanged. Use builds on the host and activation only in a disposable target.
- Add new source files to Git before a Nix command must see them.

## Driving conventions

- Start each recipe after Doctor passes.
- Run one recipe at a time because Nix commands share the local store and evaluation cache.
- Capture standard output, standard error, and the exit code.
- Wait for the command to exit. Do not infer completion from elapsed time.
- Re-run Doctor after a command changes `flake.lock` or produces an unexpected error.
- Keep proof artifacts during cleanup.

## Proof and skip reporting

- Report evaluation, build, activation, and runtime proof as separate levels.
- Do not call a successful build an activation.
- For a built closure, inspect the produced store path.
- For Pi extensions, require both the behavior tests and the type check.
- Record an unreachable activation with the target that was required.
- Do not report an untested machine configuration through another configuration.

## Feature entry contract

Each feature file uses four H2 sections in this order.

1. `Sub-features` lists stable IDs.
2. `How to get to it (user POV)` lists the maintainer commands.
3. `Driving it with terminal commands` gives exact commands and observable results.
4. `Gotchas` lists conditions that can invalidate the proof.

## Features

- [Evaluate every configuration](./evaluate-configurations.md) covers all flake outputs without building them.
- [Check Nix formatting](./check-formatting.md) covers the repository formatter in check mode.
- [Build a Linux home configuration](./build-linux-home.md) covers the Home Manager activation packages.
- [Build a macOS system configuration](./build-macos-system.md) covers the nix-darwin system closures.
- [Verify the Pi configuration](./verify-pi.md) covers extension behavior tests and TypeScript checks.
