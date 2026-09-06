{ config, pkgs, lib, ... }:

let
  repoIdentityFile = ../secrets/yubikey-identity.txt;
  hasRepoIdentity = builtins.pathExists repoIdentityFile;
in
{
  environment.systemPackages = with pkgs; [
    sops
    age
    age-plugin-yubikey
  ];

  # PC/SC daemon required for YubiKey PIV communication
  services.pcscd.enable = true;

  sops.age = {
    plugins = [ pkgs.age-plugin-yubikey ];
    generateKey = false;
    keyFile = lib.mkDefault (
      if hasRepoIdentity then
        repoIdentityFile
      else
        "/var/lib/sops-nix/key.txt"
    );
    sshKeyPaths = [ ];
  };
}
