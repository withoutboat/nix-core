{ stdenv, fetchurl, lib }:

let
  version = "0.1.8";
in
stdenv.mkDerivation {
  pname = "nixos-bootstrapper";
  inherit version;

  src = fetchurl {
    url = "https://github.com/withoutboat/nixos-bootstrapper/releases/download/v${version}/nixos-bootstrapper-linux-amd64.tar.gz";
    sha256 = "sha256-S9DVRZ/2Cl4Bsrh2eRRCO6dGHBWUxLcT6Q7oWX8pO/E="; 
  };

  sourceRoot = ".";
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp nixos-bootstrapper $out/bin/nixos-bootstrapper
    chmod +x $out/bin/nixos-bootstrapper
  '';
}
