{ ... }:

{
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      editor = "code --wait";
      aliases = {
        co = "pr checkout";
      };
    };
  };
}
