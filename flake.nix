{
  description = "Hannoeru's dotfiles, managed with nix-darwin and home-manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    antidote = {
      url = "github:mattmc3/antidote";
      flake = false;
    };

    nanorc = {
      url = "github:scopatz/nanorc";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, antidote, nanorc }:
    let
      darwinSystem = "aarch64-darwin";

      mkHome = { system, machine }: home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        extraSpecialArgs = { inherit antidote nanorc; };
        modules = [
          (import ./modules/home machine)
        ];
      };

      homeMachines = {
        # Personal headless Linux box.
        "hanlee@ubuntu" = {
          username = "hanlee";
          personal = true;
          name = "Han";
          email = "me@hanlee.co";
        };
        # Ephemeral machines (containers, devcontainers, WSL).
        hanlee = {
          username = "hanlee";
          personal = false;
          name = "Han";
          email = "me@hanlee.co";
        };
      };

      homeConfigurations =
        let
          forMachine = name: machine: {
            "${name}" = mkHome {
              system = "x86_64-linux";
              machine = machine // { os = "linux"; };
            };
            "${name}-aarch64" = mkHome {
              system = "aarch64-linux";
              machine = machine // { os = "linux"; };
            };
          };
        in
        nixpkgs.lib.foldl' (a: b: a // b) { }
          (nixpkgs.lib.mapAttrsToList forMachine homeMachines);
    in
    {
      darwinConfigurations = {
        "Han-MBP" = nix-darwin.lib.darwinSystem {
          system = darwinSystem;
          specialArgs = { inherit antidote nanorc; };
          modules = [
            ./hosts/Han-MBP.nix
            home-manager.darwinModules.home-manager
          ];
        };

        "LX-240047" = nix-darwin.lib.darwinSystem {
          system = darwinSystem;
          specialArgs = { inherit antidote nanorc; };
          modules = [
            ./hosts/LX-240047.nix
            home-manager.darwinModules.home-manager
          ];
        };
      };

      inherit homeConfigurations;
    };
}
