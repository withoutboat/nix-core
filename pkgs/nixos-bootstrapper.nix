{ stdenv, fetchurl, lib }:

let
  version = "0.1.50";
in
stdenv.mkDerivation {
  pname = "nixos-bootstrapper";
  inherit version;

  src = fetchurl {
    url = "https://github.com/withoutboat/nixos-bootstrapper/releases/download/v${version}/nixos-bootstrapper-linux-amd64.tar.gz";
    sha256 = "sha256-i37LXO3xvlTQwtS7PrtbKvVBB1TSgqw3ls+kwd0xfM4=";
  };

  sourceRoot = ".";
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp nixos-bootstrapper $out/bin/nixos-bootstrapper
    chmod +x $out/bin/nixos-bootstrapper
  '';
}
