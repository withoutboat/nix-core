{
  description = "Vladimir's Core NixOS Ecosystem Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-bootstrapper-src = {
      url = "github:withoutboat/nixos-bootstrapper/releases/download/v0.1.0/nixos-bootstrapper-linux-amd64.tar.gz";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixos-generators, nixos-bootstrapper-src, ... }@inputs:
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
    packages.${system}.iso-installer = nixos-generators.nixosGenerate {
      inherit system;
      modules = [
        { nixpkgs.pkgs = pkgs; }
        
        ./hosts/iso-installer.nix 
      ];
      format = "install-iso";
    };
  };
}
