# Build a Linux home configuration

The Linux build produces a Home Manager activation package for one declared machine. Activation is a separate user action.

## Sub-features

- `home-ephemeral-x86` builds `ephemeral`.
- `home-ephemeral-arm` builds `ephemeral-aarch64`.
- `home-personal-x86` builds `hanlee@ubuntu`.
- `home-personal-arm` builds `hanlee@ubuntu-aarch64`.
- `home-activate` applies one package only inside its matching disposable Linux target.

## How to get to it (user POV)

- Run `nix run .#home-manager -- switch -b backup --flake .#ephemeral` on x86_64 Linux.
- Use `ephemeral-aarch64` on AArch64 Linux.
- Use `hanlee@ubuntu` for the personal Linux machine.
- Build the matching `activationPackage` before an activation claim.

## Driving it with terminal commands

Preconditions:

- Doctor passes.
- Choose one exact configuration. Do not infer another configuration from it.
- Use a disposable Linux target before you run `switch`.

- **Build the package.** Replace `ephemeral` only when the changed machine requires another exact configuration.

  ```sh
  feature_dir="$VERIFY_ARTIFACT_DIR/build-linux-home"
  mkdir -p "$feature_dir"
  command='nix build --no-link --print-out-paths .#homeConfigurations.ephemeral.activationPackage'
  printf '%s\n' "$command" > "$feature_dir/command.txt"
  if nix build --no-link --print-out-paths '.#homeConfigurations.ephemeral.activationPackage' > "$feature_dir/output.log" 2>&1; then
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

- **Activation proof.** On a disposable matching Linux target, run the documented `nix run` command. Then inspect `$HOME/.aliases`, `$HOME/.config/zsh/conf.d`, the login shell, and one managed executable.
- **Proof.** The build artifacts prove the chosen activation package. Capture the disposable target transcript and inspections before you claim activation.

## Gotchas

- A build on macOS can produce a Linux closure through substitutes or remote builders. It does not create a Linux runtime.
- Personal activation can read 1Password data. Use `ephemeral` when the target must not access personal secrets.
- `switch` mutates the target home directory and profile.
- The four configurations are distinct proof targets.
