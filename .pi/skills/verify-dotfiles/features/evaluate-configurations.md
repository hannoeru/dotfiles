# Evaluate every configuration

The evaluation check proves that every declared flake output can resolve for each supported system without building or activating a configuration.

## Sub-features

- `eval-apps` evaluates the pinned Home Manager and nix-darwin apps.
- `eval-home` evaluates all Linux Home Manager configurations.
- `eval-darwin` evaluates both macOS configurations.
- `eval-formatters` evaluates each declared formatter.

## How to get to it (user POV)

- Run `scripts/check.sh` from the repository root.
- Run the same `nix flake check --all-systems --no-build` command used by the `check` CI job.

## Driving it with terminal commands

Preconditions:

- Doctor passes.
- New Nix modules and managed files are tracked by Git.

- **Run the check.** Execute the repository command and capture its status.

  ```sh
  feature_dir="$VERIFY_ARTIFACT_DIR/evaluate-configurations"
  mkdir -p "$feature_dir"
  printf '%s\n' 'scripts/check.sh' > "$feature_dir/command.txt"
  if scripts/check.sh > "$feature_dir/output.log" 2>&1; then
    status=0
  else
    status=$?
  fi
  printf '%s\n' "$status" > "$feature_dir/exit-code.txt"
  cat "$feature_dir/output.log"
  test "$status" -eq 0
  ```

- **Inspect coverage.** Confirm that the log names `darwinConfigurations.Han-MBP`, `darwinConfigurations.work`, the four `homeConfigurations`, the apps, and the formatters.
- **Proof.** Keep `command.txt`, `output.log`, and `exit-code.txt`. A zero exit code plus all named outputs proves evaluation only.

## Gotchas

- Nix can print an ignored SQLite busy message while another evaluation uses the cache. The command's final exit code decides the result.
- `--no-build` does not prove that a derivation builds.
- A local Git flake does not include untracked source files.
- Evaluation can fetch missing inputs from the network or the Nix cache.
