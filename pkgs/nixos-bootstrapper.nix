{ stdenv, nixos-bootstrapper-src, lib, ... }:

let
  hostsDir = ../hosts;
  
  hostFiles = if builtins.pathExists hostsDir 
              then builtins.attrNames (builtins.readDir hostsDir)
              else [ "pc-th.nix" ];

  discoveredHosts = lib.pipe hostFiles [
    (builtins.filter (name: lib.hasSuffix ".nix" name))
    (map (name: lib.removeSuffix ".nix" name))
    (builtins.filter (name: name != "iso-installer"))
  ];

  hostsJson = builtins.toJSON { hosts = discoveredHosts; };
in
stdenv.mkDerivation {
  pname = "nixos-bootstrapper";
  version = "0.1.5";
  
  src = nixos-bootstrapper-src;
  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp nixos-bootstrapper $out/bin/nixos-bootstrapper
    chmod +x $out/bin/nixos-bootstrapper
  '';
}
