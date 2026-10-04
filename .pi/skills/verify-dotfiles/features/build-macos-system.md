# Build a macOS system configuration

The macOS build produces one nix-darwin system closure. Activation is a separate privileged action.

## Sub-features

- `darwin-personal-build` builds `Han-MBP`.
- `darwin-work-build` builds `work`.
- `darwin-activate` applies one closure only to its matching disposable or authorized Mac.

## How to get to it (user POV)

- Run `sudo darwin-rebuild switch --flake .#Han-MBP` on the personal Mac.
- Run `sudo darwin-rebuild switch --flake .#work` on the work Mac.
- Build `darwinConfigurations.<name>.system` before an activation claim.

## Driving it with terminal commands

Preconditions:

- Doctor passes on macOS.
- Choose the configuration that matches the target Mac.
- Obtain explicit authorization before a privileged activation on a real machine.

- **Build the closure.** This recipe uses the personal configuration.

  ```sh
  feature_dir="$VERIFY_ARTIFACT_DIR/build-macos-system"
  mkdir -p "$feature_dir"
  command='nix build --no-link --print-out-paths .#darwinConfigurations.Han-MBP.system'
  printf '%s\n' "$command" > "$feature_dir/command.txt"
  if nix build --no-link --print-out-paths '.#darwinConfigurations.Han-MBP.system' > "$feature_dir/output.log" 2>&1; then
    status=0
  else
    status=$?
  fi
  printf '%s\n' "$status" > "$feature_dir/exit-code.txt"
  cat "$feature_dir/output.log"
  test "$status" -eq 0
  store_path="$(grep '^/nix/store/' "$feature_dir/output.log" | tail -n 1)"
  test -x "$store_path/activate"
  find "$store_path" -maxdepth 1 -mindepth 1 -print > "$feature_dir/store-path.txt"
  ```

- **Activation proof.** Activate only on the matching Mac. Inspect the firewall, the Remote Login state, one managed default, the Home Manager profile, and one declared Homebrew item.
- **Proof.** The closure path proves the chosen build. A privileged activation and the post-activation inspections prove the user path.

## Gotchas

- `Han-MBP` and `work` differ in secrets, host name ownership, Homebrew casks, and Remote Login.
- Building does not run Homebrew or write macOS defaults.
- Activation uses `sudo` and changes the current system.
- Do not activate a configuration on the wrong Mac.
