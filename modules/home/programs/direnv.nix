{ config, ... }:

{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    config.whitelist.prefix = [ "${config.home.homeDirectory}/projects/" ];
  };
}
