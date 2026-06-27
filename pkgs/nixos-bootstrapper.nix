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
  version = "0.1.2";
  
  src = nixos-bootstrapper-src;
  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    
    echo '${hostsJson}' > hosts.json
    echo "Baked hosts into metadata context: ${hostsJson}"

    TARGET_BIN=$(find . -type f -name "*nixos-bootstrapper*" | head -n 1)
    if [ -z "$TARGET_BIN" ]; then
      echo "Error: Binary not found in source archive!"
      exit 1
    fi
    
    cp "$TARGET_BIN" $out/bin/nixos-bootstrapper
    chmod +x $out/bin/nixos-bootstrapper
    
    cp hosts.json $out/bin/
  '';
}
