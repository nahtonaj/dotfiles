{
  description = "jon.gao dotfiles — Nix Flake + Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, ... }:
    let
      linuxSystem = "x86_64-linux";
      darwinSystem = "aarch64-darwin";
    in
    {
      # Standalone home-manager for Linux
      homeConfigurations."jon.gao@linux" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = linuxSystem;
          config.allowUnfree = true;
        };
        extraSpecialArgs = { flakePath = self; };
        modules = [
          ./nix/home/default.nix
          ./nix/home/linux.nix
        ];
      };

      # nix-darwin + home-manager for macOS
      darwinConfigurations."jon.gao-mac" = nix-darwin.lib.darwinSystem {
        system = darwinSystem;
        specialArgs = { flakePath = self; };
        modules = [
          ./nix/hosts/darwin.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { flakePath = self; };
            home-manager.users."jon.gao" = { ... }: {
              imports = [
                ./nix/home/default.nix
                ./nix/home/darwin.nix
              ];
            };
          }
        ];
      };
    };
}
