{ stdenv, nixos-bootstrapper-src }:

stdenv.mkDerivation {
  pname = "nixos-bootstrapper";
  version = "0.1.1";
  
  src = nixos-bootstrapper-src;

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    ls -R
    TARGET_BIN=$(find . -type f -name "*nixos-bootstrapper*" | head -n 1)
    
    if [ -z "$TARGET_BIN" ]; then
      exit 1
    fi
    
    cp "$TARGET_BIN" $out/bin/nixos-bootstrapper
    chmod +x $out/bin/nixos-bootstrapper
  '';
}
