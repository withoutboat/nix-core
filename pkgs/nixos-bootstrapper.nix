{ stdenv, fetchurl, lib }:

let
  version = "0.1.46";
in
stdenv.mkDerivation {
  pname = "nixos-bootstrapper";
  inherit version;

  src = fetchurl {
    url = "https://github.com/withoutboat/nixos-bootstrapper/releases/download/v${version}/nixos-bootstrapper-linux-amd64.tar.gz";
    sha256 = "sha256-CQchplRdPCaB8UCpxMa23sKFHRP05NK+l0bwGI2fLOU=";
  };

  sourceRoot = ".";
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp nixos-bootstrapper $out/bin/nixos-bootstrapper
    chmod +x $out/bin/nixos-bootstrapper
  '';
}
