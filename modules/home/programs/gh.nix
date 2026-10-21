{ pkgs, ... }:

{
  programs.gh = {
    enable = true;
    extensions = [ pkgs.gh-poi ];
    settings = {
      git_protocol = "https";
      editor = "code --wait";
      aliases = {
        co = "pr checkout";
      };
    };
  };
}
