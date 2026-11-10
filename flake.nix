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

    mattpocock = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    shadcnImprove = {
      url = "github:shadcn/improve";
      flake = false;
    };

    jscpd = {
      url = "github:kucherenko/jscpd";
      flake = false;
    };

    simpleEnglish = {
      url = "github:AminBlg/SimpleEnglish";
      flake = false;
    };

    cursorPlugins = {
      url = "github:cursor/plugins";
      flake = false;
    };

    iHaveAdhd = {
      url = "github:ayghri/i-have-adhd";
      flake = false;
    };

    antfu = {
      url = "github:antfu/skills";
      flake = false;
    };

    vuejs = {
      url = "github:vuejs-ai/skills";
      flake = false;
    };

    nuxt = {
      url = "github:onmax/nuxt-skills";
      flake = false;
    };

    anthropics = {
      url = "github:anthropics/skills";
      flake = false;
    };

    agentBrowser = {
      url = "github:vercel-labs/agent-browser";
      flake = false;
    };

    herdr = {
      url = "github:herdrdev/herdr";
      flake = false;
    };

    # Keep equal to npm:@zenspc/pi-pstack@<version> in ~/.pi/agent/settings.json.
    pstack = {
      url = "https://registry.npmjs.org/@zenspc/pi-pstack/-/pi-pstack-0.9.0.tgz";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      nanorc,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      machines = import ./machines.nix;
      skillInputs = {
        inherit (inputs)
          mattpocock
          shadcnImprove
          jscpd
          simpleEnglish
          cursorPlugins
          iHaveAdhd
          antfu
          vuejs
          nuxt
          anthropics
          agentBrowser
          herdr
          pstack
          ;
      };

      mkHome =
        { system, machine }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = { inherit machine nanorc skillInputs; };
          modules = [ ./modules/home ];
        };
    in
    {
      darwinConfigurations = lib.mapAttrs (
        _name: machine:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit machine nanorc skillInputs; };
          modules = [
            ./modules/darwin.nix
            home-manager.darwinModules.home-manager
            { system.configurationRevision = self.rev or self.dirtyRev or null; }
          ];
        }
      ) (lib.filterAttrs (_name: machine: machine.os == "darwin") machines);

      homeConfigurations = lib.concatMapAttrs (name: machine: {
        "${name}" = mkHome {
          system = "x86_64-linux";
          inherit machine;
        };
        "${name}-aarch64" = mkHome {
          system = "aarch64-linux";
          inherit machine;
        };
      }) (lib.filterAttrs (_name: machine: machine.os == "linux") machines);

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
        // lib.genAttrs [ "aarch64-darwin" ] (system: {
          darwin-rebuild =
            mkApp
              (import nixpkgs {
                inherit system;
                overlays = [ nix-darwin.overlays.default ];
              }).darwin-rebuild;
        });

      formatter = lib.genAttrs [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ] (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # statix fix takes one path per run; treefmt passes many files.
          statix-files = pkgs.writeShellApplication {
            name = "statix-files";
            runtimeInputs = [ pkgs.statix ];
            text = ''
              for file in "$@"; do
                statix fix "$file"
                statix check "$file"
              done
            '';
          };
        in
        pkgs.nixfmt-tree.override {
          runtimeInputs = [
            pkgs.deadnix
            statix-files
          ];
          settings.formatter = {
            deadnix = {
              command = "deadnix";
              options = [ "--edit" ];
              includes = [ "*.nix" ];
              priority = 1;
            };
            statix = {
              command = "statix-files";
              includes = [ "*.nix" ];
              priority = 2;
            };
            nixfmt.priority = 3;
          };
        }
      );
    };
}
