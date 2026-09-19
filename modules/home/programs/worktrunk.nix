{ lib, pkgs, ... }:

let
  wt = lib.getExe pkgs.worktrunk;
in
{
  home.packages = [ pkgs.worktrunk ];

  # `wt config shell install` would append to the home-manager-generated
  # .zshrc and be overwritten on the next rebuild, so declare it instead.
  programs.zsh.initContent = ''
    eval "$(${wt} config shell init zsh)"
  '';
}
