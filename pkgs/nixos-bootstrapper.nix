{ stdenv, fetchurl, lib }:

let
  version = "0.1.5";
in
stdenv.mkDerivation {
  pname = "nixos-bootstrapper";
  inherit version;

  src = fetchurl {
    url = "https://github.com/withoutboat/nixos-bootstrapper/releases/download/v${version}/nixos-bootstrapper-linux-amd64";
    sha256 = lib.fakeSha256; 
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/nixos-bootstrapper
    chmod +x $out/bin/nixos-bootstrapper
  '';
}
