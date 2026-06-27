{ stdenv, nixos-bootstrapper-src }:

stdenv.mkDerivation {
  pname = "nixos-bootstrapper";
  version = "0.1.0";
  
  src = nixos-bootstrapper-src;

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp nixos-bootstrapper $out/bin/
    chmod +x $out/bin/nixos-bootstrapper
  '';
}
