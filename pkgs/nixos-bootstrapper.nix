{ stdenv, fetchurl, lib }:

let
  version = "0.1.14";
in
stdenv.mkDerivation {
  pname = "nixos-bootstrapper";
  inherit version;

  src = fetchurl {
    url = "https://github.com/withoutboat/nixos-bootstrapper/releases/download/v${version}/nixos-bootstrapper-linux-amd64.tar.gz";
    sha256 = "sha256-mrAlmLky4IvfMHGiMAhwqQ+1rW8fNOKnNUFMC0zghkY="; 
  };

  sourceRoot = ".";
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp nixos-bootstrapper $out/bin/nixos-bootstrapper
    chmod +x $out/bin/nixos-bootstrapper
  '';
}
