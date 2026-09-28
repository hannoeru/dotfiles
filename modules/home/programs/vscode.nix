{
  programs.vscode = {
    enable = true;
    package = null;
    mutableExtensionsDir = true;
    profiles.default.userSettings = ../../../home/.config/Code/User/settings.json;
  };

  home.file.".config/cspell/user-words.txt".source = ../../../home/.config/cspell/user-words.txt;
}
