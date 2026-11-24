{
  config,
  lib,
  pkgs,
  machine,
  ...
}:

let
  claudeSessionHook = pkgs.writeShellApplication {
    name = "rex-claude-session-hook";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      input="$(cat)"
      if [ -z "''${REX_BLOCK:-}" ] || [ "''${HERDR_ENV:-}" = 1 ]; then
        exit 0
      fi
      # Skip claude -p and other runs that another program started in this
      # terminal; only the terminal's foreground Claude owns the pane.
      read -r pgid tpgid <<<"$(ps -o pgid=,tpgid= -p "$PPID")"
      [ "$pgid" = "$tpgid" ] || exit 0
      session="$(jq -r 'select((.agent_id // "") == "") | .session_id // empty' <<<"$input")"
      [ -n "$session" ] || exit 0
      cwd="$(jq -r '.cwd // empty' <<<"$input")"
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/rex-agent-sessions"
      mkdir -p "$state_dir"
      printf 'claude\n%s\n%s\n%s\n' "$session" "''${cwd:-$PWD}" "$PPID" >"$state_dir/''${REX_BLOCK#block:}"
    '';
  };

  hookCommand = "${config.home.profileDirectory}/bin/rex-claude-session-hook";

  rexThemes = pkgs.writers.writePython3 "rex-themes" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./rex-themes.py);

  # Fixed IDs let each switch replace the same two entries in Rex's theme list.
  vitesse = {
    dark = "custom-27F2B641-C9C6-4C3B-BE01-B664D821BD9F";
    light = "custom-E118506D-0BF1-4E23-8F2D-C7ACBDEDED36";
  };

  themeSpec = pkgs.writeText "rex-themes.json" (
    builtins.toJSON (
      lib.mapAttrsToList (appearance: id: {
        inherit id appearance;
        name = "Vitesse ${lib.toSentenceCase appearance}";
        fileName = "vitesse-${appearance}";
        path = config.xdg.configFile."ghostty/themes/vitesse-${appearance}".source;
      }) vitesse
    )
  );
in
{
  config = lib.mkIf (machine.os == "darwin") {
    # Rex keeps state in ~/.config/rex, so link only the files it reads.
    home.file.".config/rex/init.lua".source = ../../../home/.config/rex/init.lua;
    home.file.".config/rex/agent-resume.lua".source = ../../../home/.config/rex/agent-resume.lua;

    home.packages = [ claudeSessionHook ];

    # Claude Code, Herdr, and Rex all edit ~/.claude/settings.json, so add the
    # hook to the file instead of owning it. The hook path is stable across
    # generations, which keeps this step idempotent.
    home.activation.rexClaudeSessionHook = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      settings="$HOME/.claude/settings.json"
      if [ -f "$settings" ]; then
        tmp="$(mktemp)"
        if ${lib.getExe pkgs.jq} --arg cmd ${lib.escapeShellArg hookCommand} '
          .hooks.SessionStart = [(.hooks.SessionStart // [])[] | select(all(.hooks[]?; .command != $cmd))]
            + [{hooks: [{type: "command", command: $cmd, timeout: 5}]}]
        ' "$settings" >"$tmp" && ! cmp -s "$tmp" "$settings"; then
          $DRY_RUN_CMD cp "$tmp" "$settings"
        fi
        rm -f "$tmp"
      fi
    '';

    # Rex keeps custom themes as a JSON list in its defaults, in the format that
    # its Ghostty theme import writes. Add the Ghostty Vitesse themes to that
    # list and select them, as Ghostty does.
    home.activation.rexVitesseTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      themes="$(${rexThemes} ${themeSpec})"
      if [ -n "$themes" ]; then
        $DRY_RUN_CMD /usr/bin/defaults write com.superlogical.rex Workspace.customThemes -data "$themes"
      fi
      $DRY_RUN_CMD /usr/bin/defaults write com.superlogical.rex Workspace.darkThemeID -string ${vitesse.dark}
      $DRY_RUN_CMD /usr/bin/defaults write com.superlogical.rex Workspace.lightThemeID -string ${vitesse.light}
    '';
  };
}
