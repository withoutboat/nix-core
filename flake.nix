{
  description = "Vladimir's Core NixOS Ecosystem Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-home = {
      url = "github:withoutboat/nix-home";
      flake = true;
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-home, ... }@inputs:
  let
    system = "x86_64-linux";
    
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        (import ./pkgs)
      ];
    };
  in {
    packages.${system}.iso-installer = (nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        { nixpkgs.pkgs = pkgs; }
        ./hosts/iso-installer.nix 
      ];
    }).config.system.build.isoImage;

    nixosConfigurations.pc-th = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };

      modules = [
        { nixpkgs.pkgs = pkgs; }

        ./hosts/pc-th.nix
        ./hardware.nix
        home-manager.nixosModules.home-manager
      ];
    };
  };
}
