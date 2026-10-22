{ pkgs, ... }:

{
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
    extensions = [ pkgs.gh-poi ];
    settings = {
      git_protocol = "https";
      expiring_credentials = "enabled";
      editor = "code --wait";
      aliases = {
        co = "pr checkout";
      };
    };
  };
}
