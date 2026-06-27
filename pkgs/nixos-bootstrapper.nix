{ stdenv, nixos-bootstrapper-src }:

stdenv.mkDerivation {
  pname = "nixos-bootstrapper";
  version = "0.1.1"; 
  
  src = nixos-bootstrapper-src;
  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp nixos-bootstrapper $out/bin/
    chmod +x $out/bin/nixos-bootstrapper
  '';
}
