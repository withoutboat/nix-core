{ stdenv, nixos-bootstrapper-src }:

stdenv.mkDerivation {
  pname = "nixos-bootstrapper";
  version = "0.1.0";
  
  src = nixos-bootstrapper-src;

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    
    TARGET_BIN=$(find . -type f -name "nixos-bootstrapper*" | head -n 1)
    
    if [ -z "$TARGET_BIN" ]; then
      echo "Error: Cannot find any file matching 'nixos-bootstrapper*' in the archive!"
      ls -R
      exit 1
    fi
    
    echo "Found binary at $TARGET_BIN, copying to $out/bin/nixos-bootstrapper"
    cp "$TARGET_BIN" $out/bin/nixos-bootstrapper
    
    chmod +x $out/bin/nixos-bootstrapper
  '';
}
