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

  # Declaratively symlink identity stub from repo to /etc
  environment.etc = lib.mkIf hasRepoIdentity {
    "sops/age/keys.txt".source = repoIdentityFile;
  };

  sops.age = {
    plugins = [ pkgs.age-plugin-yubikey ];
    generateKey = false;
    keyFile = lib.mkDefault (
      if hasRepoIdentity then
        "/etc/sops/age/keys.txt"
      else
        "/var/lib/sops-nix/key.txt"
    );
    sshKeyPaths = [ ];
  };

  # Ensure /etc symlinks are created before sops decrypts secrets
  system.activationScripts = lib.mkIf (hasRepoIdentity && config.sops.secrets != { }) {
    setupSecrets.deps = [ "etc" ];
  };
}
