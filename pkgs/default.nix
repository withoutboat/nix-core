{ nixos-bootstrapper-src }:

final: prev: {
  nixos-bootstrapper = final.callPackage ./nixos-bootstrapper.nix {
    inherit nixos-bootstrapper-src;
  };

}
