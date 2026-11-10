{ machine, pkgs, ... }:

{
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
    extensions = [ pkgs.gh-poi ];
    settings = {
      git_protocol = "https";
      expiring_credentials = "enabled";
      editor = if machine.os == "darwin" then "code --wait" else "nano";
      aliases = {
        co = "pr checkout";
      };
    };
  };
}
