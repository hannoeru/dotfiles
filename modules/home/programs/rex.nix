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

  vitesse = {
    dark = "custom-27F2B641-C9C6-4C3B-BE01-B664D821BD9F";
    light = "custom-E118506D-0BF1-4E23-8F2D-C7ACBDEDED36";
  };

  rgb = red: green: blue: {
    red = red / 255.0;
    green = green / 255.0;
    blue = blue / 255.0;
    alpha = 1;
    colorSpace = "srgb";
  };
  hex = value: rgb (byte value 1) (byte value 3) (byte value 5);
  byte = value: start: lib.fromHexString (builtins.substring start 2 value);

  xtermSteps = [
    0
    95
    135
    175
    215
    255
  ];
  xterm =
    index:
    if index < 232 then
      let
        cube = index - 16;
        step = n: builtins.elemAt xtermSteps (lib.mod n 6);
      in
      rgb (step (cube / 36)) (step (cube / 6)) (step cube)
    else
      let
        gray = 8 + 10 * (index - 232);
      in
      rgb gray gray gray;

  # The entry shape that Rex's Ghostty theme import writes.
  rexTheme =
    appearance: id:
    let
      ghostty = lib.mapAttrs (_: lib.last) config.programs.ghostty.themes."vitesse-${appearance}";
      ansi = lib.listToAttrs (
        map (
          entry:
          let
            parts = lib.splitString "=" entry;
          in
          lib.nameValuePair (lib.head parts) (lib.last parts)
        ) config.programs.ghostty.themes."vitesse-${appearance}".palette
      );
    in
    {
      inherit id appearance;
      name = "Vitesse ${lib.toSentenceCase appearance}";
      source.ghosttyFile.fileName = "vitesse-${appearance}";
      createdAt = 0;
      palette = {
        background = hex ghostty.background;
        foreground = hex ghostty.foreground;
        cursor = hex ghostty.cursor-color;
        cursorText = hex ghostty.cursor-text;
        selectionBackground = hex ghostty.selection-background;
        selectionForeground = hex ghostty.selection-foreground;
        ansi = lib.genList (index: hex ansi.${toString index}) 16;
        paletteBase = lib.listToAttrs (
          lib.genList (index: lib.nameValuePair (toString (index + 16)) (xterm (index + 16))) 240
        );
        paletteGenerate = false;
        paletteHarmonious = false;
        paletteOverrides = { };
      };
    };

  rexThemes = pkgs.writeText "rex-themes.json" (
    builtins.toJSON (lib.mapAttrsToList rexTheme vitesse)
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

    # Rex keeps its custom themes as JSON bytes in its defaults and has no
    # config option for them, so own the list and select Vitesse as Ghostty does.
    home.activation.rexVitesseTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      $DRY_RUN_CMD /usr/bin/defaults write com.superlogical.rex Workspace.customThemes \
        -data "$(/usr/bin/xxd -p ${rexThemes} | tr -d '\n')"
      $DRY_RUN_CMD /usr/bin/defaults write com.superlogical.rex Workspace.darkThemeID -string ${vitesse.dark}
      $DRY_RUN_CMD /usr/bin/defaults write com.superlogical.rex Workspace.lightThemeID -string ${vitesse.light}
    '';
  };
}
