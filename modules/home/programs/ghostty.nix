{ ... }:

{
  programs.ghostty = {
    enable = true;
    # The app itself comes from the Homebrew cask on macOS.
    package = null;
    # Config-only on Linux; there is no ghostty binary to wrap in a service.
    systemd.enable = false;
    settings ={
      theme = "dark:vitesse-dark,light:vitesse-light";
      font-family = "MesloLGS Nerd Font Mono";
      font-size = 14;
      font-thicken = true;
      font-synthetic-style = true;
      window-padding-x = 10;
      background-opacity = 0.95;
      background-blur-radius = 20;
      cursor-style = "underline";
      cursor-style-blink = true;
      scrollback-limit = 100000;
      mouse-hide-while-typing = true;
      copy-on-select = false;
      clipboard-read = "allow";
      clipboard-write = "allow";
      shell-integration = "detect";
      shell-integration-features = true;
      unfocused-split-opacity = 0.8;
      confirm-close-surface = false;
      macos-titlebar-style = "tabs";
      macos-option-as-alt = true;
      keybind = [
        "super+c=copy_to_clipboard"
        "super+v=paste_from_clipboard"
        "super+t=new_tab"
        "super+w=close_surface"
        "super+n=new_window"
        "super+shift+left_bracket=previous_tab"
        "super+shift+right_bracket=next_tab"
        "super+equal=increase_font_size:1"
        "super+minus=decrease_font_size:1"
        "super+zero=reset_font_size"
      ];
    };
    themes ={
        vitesse-dark = {
          background = "#121212";
          foreground = "#dbdaca";
          cursor-color = "#dbdaca";
          cursor-text = "#121212";
          selection-background = "#4d9375";
          selection-foreground = "#121212";
          palette = [
            "0=#393a34"
            "1=#cb7676"
            "2=#4d9375"
            "3=#e6cc77"
            "4=#6394bf"
            "5=#d9739f"
            "6=#5eaab5"
            "7=#dbdaca"
            "8=#777777"
            "9=#cb7676"
            "10=#4d9375"
            "11=#e6cc77"
            "12=#6394bf"
            "13=#d9739f"
            "14=#5eaab5"
            "15=#ffffff"
          ];
        };
        vitesse-light = {
          background = "#ffffff";
          foreground = "#393a34";
          cursor-color = "#393a34";
          cursor-text = "#ffffff";
          selection-background = "#1c6b48";
          selection-foreground = "#ffffff";
          palette = [
            "0=#121212"
            "1=#ab5959"
            "2=#1e754f"
            "3=#bda437"
            "4=#296aa3"
            "5=#a13865"
            "6=#2993a3"
            "7=#dbdaca"
            "8=#aaaaaa"
            "9=#ab5959"
            "10=#1e754f"
            "11=#bda437"
            "12=#296aa3"
            "13=#a13865"
            "14=#2993a3"
            "15=#dddddd"
          ];
        };
      };
  };
}
