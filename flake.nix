{
  description = "Vladimir's Core NixOS Ecosystem Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-bootstrapper-src = {
      url = "github:withoutboat/nixos-bootstrapper/releases/download/v0.1.1/nixos-bootstrapper-linux-amd64.tar.gz";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixos-bootstrapper-src, ... }@inputs:
  let
    system = "x86_64-linux";
    
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        (import ./pkgs { inherit nixos-bootstrapper-src; })
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
      modules = [
        { nixpkgs.pkgs = pkgs; }

        ./hosts/pc-th.nix
        
      ];
    };
  };
}
