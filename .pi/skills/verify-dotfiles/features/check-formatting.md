# Check Nix formatting

The formatter check proves that the repository's tracked Nix files already match the `nixfmt-tree` output.

## Sub-features

- `format-discovery` traverses the repository through the flake formatter.
- `format-clean` exits successfully only when formatting changes no file.

## How to get to it (user POV)

- Run `nix fmt` to format the repository.
- Run `nix fmt -- --ci` to check formatting without accepting changes.
- Use the same check command as the `format` CI job.

## Driving it with terminal commands

Preconditions:

- Doctor passes.
- Every Nix source file needed by the formatter is tracked by Git.

- **Run check mode.** Capture the formatter output and status.

  ```sh
  feature_dir="$VERIFY_ARTIFACT_DIR/check-formatting"
  mkdir -p "$feature_dir"
  printf '%s\n' 'nix fmt -- --ci' > "$feature_dir/command.txt"
  if nix fmt -- --ci > "$feature_dir/output.log" 2>&1; then
    status=0
  else
    status=$?
  fi
  printf '%s\n' "$status" > "$feature_dir/exit-code.txt"
  cat "$feature_dir/output.log"
  test "$status" -eq 0
  grep -Fq '(0 changed)' "$feature_dir/output.log"
  ```

- **Inspect the result.** Require a zero exit code and a reported count of zero changed files.
- **Proof.** Keep the command log and exit code.

## Gotchas

- Plain `nix fmt` can rewrite files. Use `-- --ci` for verification.
- The `--` passes `--ci` to `nixfmt-tree`.
- The formatter traverses repository files. Its reported file count can change when files are added or removed.
