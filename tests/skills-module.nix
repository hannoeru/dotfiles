{
  system ? builtins.currentSystem,
  source ? ./fixtures,
  category ? "fixture",
}:
let
  flake = builtins.getFlake (toString ../.);
  pkgs = flake.inputs.nixpkgs.legacyPackages.${system};
  home = flake.inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../modules/home/programs/skills.nix
      {
        home.username = "skills-test";
        home.homeDirectory = "/tmp/skills-test";
        home.stateVersion = "25.05";
        programs.skills.sources = [
          {
            source = toString source;
            inherit category;
          }
        ];
      }
    ];
  };
in
{
  wrapper = builtins.head home.config.home.packages;
  inherit (pkgs) skills python3;
  sources = home.config.programs.skills.sources;
  activation = home.config.home.activation.skills.data;
}
