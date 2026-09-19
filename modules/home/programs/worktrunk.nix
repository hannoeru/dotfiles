{ lib, pkgs, machine, ... }:

let
  wt = lib.getExe pkgs.worktrunk;

  # herdr can be a Homebrew or curl-installed binary, so it may not be on PATH
  # during activation; find it the same way the 1Password helper does.
  findHerdr = ''
    herdr_bin="$(command -v herdr || true)"
    if [ -z "$herdr_bin" ]; then
      for candidate in /opt/homebrew/bin/herdr "$HOME/.local/bin/herdr"; do
        if [ -x "$candidate" ]; then
          herdr_bin="$candidate"
          break
        fi
      done
    fi
  '';
in
{
  config = lib.mkIf (machine.os == "darwin") {
    home.packages = [ pkgs.worktrunk ];

    # `wt config shell install` would append to the home-manager-generated
    # .zshrc and be overwritten on the next rebuild, so declare it instead.
    programs.zsh.initContent = ''
      eval "$(${wt} config shell init zsh)"
    '';

    home.file.".config/herdr/plugins/worktrunk" = {
      source = ../../../home/.config/herdr/plugins/worktrunk;
      recursive = true;
    };

    # herdr registers linked plugins outside the Nix store, so re-link on each
    # rebuild; the step is a no-op when herdr is absent or already linked.
    home.activation.linkWorktrunkPlugin = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${findHerdr}
      if [ -n "$herdr_bin" ]; then
        $DRY_RUN_CMD "$herdr_bin" plugin link "$HOME/.config/herdr/plugins/worktrunk" >/dev/null 2>&1 || true
      fi
    '';
  };
}
