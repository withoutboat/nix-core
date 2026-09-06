{
  description = "Vladimir's Core NixOS Ecosystem Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-home = {
      url = "github:withoutboat/nix-home";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-home, sops-nix, nur, stylix, ... }@inputs:
  let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        (import ./pkgs)
        nur.overlays.default
      ];
    };
  in
  {
    packages.${system}.iso-installer = (nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        { nixpkgs.pkgs = pkgs; }
        ./hosts/iso-installer/default.nix
      ];
    }).config.system.build.isoImage;

    nixosConfigurations.pc-th = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs self; };

      modules = [
        { nixpkgs.pkgs = pkgs; }
        ./hosts/pc-th/default.nix
        home-manager.nixosModules.home-manager
        sops-nix.nixosModules.sops
        stylix.nixosModules.stylix
      ];
    };
  };

}
