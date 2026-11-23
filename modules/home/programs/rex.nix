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
      session="$(jq -r 'select((.agent_id // "") == "") | .session_id // empty' <<<"$input")"
      [ -n "$session" ] || exit 0
      cwd="$(jq -r '.cwd // empty' <<<"$input")"
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/rex-agent-sessions"
      mkdir -p "$state_dir"
      printf 'claude\n%s\n%s\n' "$session" "''${cwd:-$PWD}" >"$state_dir/''${REX_BLOCK#block:}"
    '';
  };

  hookCommand = "${config.home.profileDirectory}/bin/rex-claude-session-hook";
in
{
  config = lib.mkIf (machine.os == "darwin") {
    # Rex keeps state in ~/.config/rex, so link only the config file.
    home.file.".config/rex/init.lua".source = ../../../home/.config/rex/init.lua;

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

    # A record in rex-agent-sessions means an agent was still running when
    # the terminal ended. Any prompt in the same Rex block clears it, so only
    # a terminal that the Rex server restored finds it and resumes the agent.
    programs.zsh.initContent = ''
      if [[ -n ''${REX_BLOCK:-} && ''${HERDR_ENV:-} != 1 ]]; then
        _rex_agent_session_file=''${XDG_STATE_HOME:-$HOME/.local/state}/rex-agent-sessions/''${REX_BLOCK#block:}

        _rex_agent_session_resume() {
          add-zsh-hook -d precmd _rex_agent_session_resume
          [[ -r $_rex_agent_session_file ]] || return 0
          local agent session dir
          { read -r agent; read -r session; read -r dir } <"$_rex_agent_session_file"
          [[ -d $dir ]] && cd -- "$dir"
          case $agent in
            claude) claude --resume "$session" ;;
            pi) pi --session "$session" ;;
          esac
        }

        _rex_agent_session_clear() {
          rm -f -- "$_rex_agent_session_file"
        }

        autoload -Uz add-zsh-hook
        add-zsh-hook precmd _rex_agent_session_resume
        add-zsh-hook precmd _rex_agent_session_clear
      fi
    '';
  };
}
