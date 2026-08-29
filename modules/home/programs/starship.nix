{ ... }:

{
  programs.starship = {
    enable = true;
    settings = {
      "$schema" = "https://starship.rs/config-schema.json";
      add_newline = true;
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[✖](bold red)";
      };
      aws = {
        format = "on [$symbol($profile )(\\($region\\) )]($style)";
        style = "bold blue";
        symbol = " ";
        region_aliases = {
          ap-northeast-1 = "jp";
          ap-southeast-2 = "au";
          us-east-1 = "va";
        };
      };
      azure = {
        format = "on [$symbol($subscription)]($style) ";
        symbol = "ﴃ ";
        style = "bold blue";
      };
      gcloud = {
        disabled = true;
        format = "[$symbol$active]($style) ";
        symbol = "️ ";
        style = "bold yellow";
      };
      buf = {
        symbol = " ";
      };
      c = {
        symbol = " ";
      };
      conda = {
        symbol = " ";
      };
      dart = {
        symbol = " ";
      };
      directory = {
        read_only = " ";
      };
      docker_context = {
        symbol = " ";
      };
      elixir = {
        symbol = " ";
      };
      elm = {
        symbol = " ";
      };
      git_branch = {
        symbol = " ";
      };
      golang = {
        symbol = " ";
      };
      haskell = {
        symbol = " ";
      };
      hg_branch = {
        symbol = " ";
      };
      java = {
        symbol = " ";
      };
      julia = {
        symbol = " ";
      };
      memory_usage = {
        symbol = " ";
      };
      nim = {
        symbol = " ";
      };
      nix_shell = {
        symbol = " ";
      };
      nodejs = {
        symbol = " ";
      };
      package = {
        symbol = " ";
      };
      python = {
        symbol = " ";
      };
      spack = {
        symbol = "🅢 ";
      };
      rust = {
        symbol = " ";
      };
    };
  };
}
