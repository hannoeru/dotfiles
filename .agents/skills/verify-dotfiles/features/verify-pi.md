# Verify the Pi configuration

The Pi checks prove the behavior of the project-managed extensions and confirm that TypeScript accepts their interfaces.

## Sub-features

- `pi-install` installs the lockfile exactly.
- `pi-behavior` runs the extension behavior tests.
- `pi-types` type-checks the extension source.

## How to get to it (user POV)

- Enter `home/.pi`.
- Run `pnpm install --frozen-lockfile`.
- Run `pnpm test`.
- Run `pnpm typecheck`.

## Driving it with terminal commands

Preconditions:

- Doctor reports a `pnpm` executable.
- The network or pnpm store can provide every locked package.

- **Install and check.** Run the documented sequence.

  ```sh
  feature_dir="$VERIFY_ARTIFACT_DIR/verify-pi"
  mkdir -p "$feature_dir"
  printf '%s\n' 'cd home/.pi && pnpm install --frozen-lockfile && pnpm test && pnpm typecheck' > "$feature_dir/command.txt"
  if (
    cd home/.pi
    pnpm install --frozen-lockfile
    pnpm test
    pnpm typecheck
  ) > "$feature_dir/output.log" 2>&1; then
    status=0
  else
    status=$?
  fi
  printf '%s\n' "$status" > "$feature_dir/exit-code.txt"
  cat "$feature_dir/output.log"
  test "$status" -eq 0
  ```

- **Inspect behavior coverage.** Require all test files and tests to pass. Require the type checker to exit without an error.
- **Proof.** Keep the combined log and exit code. Name the extension test file when a change affects only one extension.

## Gotchas

- `pnpm install` can populate the ignored `node_modules` directory.
- A type check does not prove extension behavior.
- A test pass does not prove that Home Manager deployed `home/.pi`.
- Pi runtime behavior outside the tested extension paths needs a separate interactive Pi run.
