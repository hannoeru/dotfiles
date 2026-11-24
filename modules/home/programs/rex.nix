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
  };
}
