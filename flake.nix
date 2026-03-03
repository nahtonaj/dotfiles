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

    normalNvim = {
      url = "github:nahtonaj/NormalNvim/a8ac5eafc0bd88f9575219ff1de1bc62c51f88af";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, normalNvim, ... }:
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
        extraSpecialArgs = { flakePath = self; inherit normalNvim; };
        modules = [
          ./nix/home/default.nix
          ./nix/home/linux.nix
        ];
      };

      # nix-darwin + home-manager for macOS
      darwinConfigurations."jon.gao-mac" = nix-darwin.lib.darwinSystem {
        system = darwinSystem;
        specialArgs = { flakePath = self; inherit normalNvim; };
        modules = [
          ./nix/hosts/darwin.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { flakePath = self; inherit normalNvim; };
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
