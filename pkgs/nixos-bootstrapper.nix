{ stdenv, nixos-bootstrapper-src }:

stdenv.mkDerivation {
  pname = "nixos-bootstrapper";
  version = "0.1.0";
  
  src = nixos-bootstrapper-src;

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    
    find . -type f -executable -exec cp {} $out/bin/nixos-bootstrapper \;
    
    if [ ! -f $out/bin/nixos-bootstrapper ]; then
      echo "Error: No executable binary found in the release archive structure!"
      exit 1
    fi
    
    chmod +x $out/bin/nixos-bootstrapper
  '';
}
