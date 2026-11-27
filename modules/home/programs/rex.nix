{
  config,
  lib,
  pkgs,
  machine,
  ...
}:

let
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
      theme = config.programs.ghostty.themes."vitesse-${appearance}";
      ghostty = lib.mapAttrs (_: lib.last) theme;
      ansi = lib.listToAttrs (
        map (
          entry:
          let
            parts = lib.splitString "=" entry;
          in
          lib.nameValuePair (lib.head parts) (lib.last parts)
        ) theme.palette
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
