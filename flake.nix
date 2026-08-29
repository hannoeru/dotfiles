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

    nanorc = {
      url = "github:scopatz/nanorc";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      nanorc,
    }:
    let
      lib = nixpkgs.lib;
      machines = import ./machines.nix;

      mkHome =
        { system, machine }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = { inherit machine nanorc; };
          modules = [ ./modules/home ];
        };
    in
    {
      darwinConfigurations = lib.mapAttrs (
        name: machine:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit machine nanorc; };
          modules = [
            ./modules/darwin.nix
            home-manager.darwinModules.home-manager
          ];
        }
      ) (lib.filterAttrs (name: machine: machine.os == "darwin") machines);

      homeConfigurations = lib.concatMapAttrs (name: machine: {
        "${name}" = mkHome {
          system = "x86_64-linux";
          inherit machine;
        };
        "${name}-aarch64" = mkHome {
          system = "aarch64-linux";
          inherit machine;
        };
      }) (lib.filterAttrs (name: machine: machine.os == "linux") machines);

      # Pinned entry points so bootstrap does not depend on the global
      # flake registry.
      apps =
        let
          mkApp = pkg: {
            type = "app";
            program = lib.getExe pkg;
          };
        in
        lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: {
          home-manager = mkApp home-manager.packages.${system}.home-manager;
        })
        // lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" ] (system: {
          darwin-rebuild = mkApp (
            (import nixpkgs {
              inherit system;
              overlays = [ nix-darwin.overlays.default ];
            }).darwin-rebuild
          );
        });

      formatter = lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ] (
        system: nixpkgs.legacyPackages.${system}.nixfmt
      );
    };
}
