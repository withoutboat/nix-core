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

  sops = {
    useSystemdActivation = true;
    age = {
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
  };

  # Ensure sops-install-secrets runs after pcscd.socket is available
  systemd.services.sops-install-secrets = lib.mkIf config.sops.useSystemdActivation {
    after = [ "pcscd.socket" ];
    wants = [ "pcscd.socket" ];
  };

  # Automatically trigger secret installation and dependent services when YubiKey is inserted
  services.udev.extraRules = lib.mkIf (config.sops.useSystemdActivation && config.sops.secrets != { }) ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="1050", TAG+="systemd", ENV{SYSTEMD_WANTS}+="sops-install-secrets.service"
  '';
}
