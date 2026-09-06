{ config, pkgs, lib, ... }:

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
    keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";
    sshKeyPaths = [ ];
  };
}
