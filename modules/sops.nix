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
    keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";
    sshKeyPaths = [ ];
  };

  # sops-nix requires sops.age.keyFile to be a path outside the Nix store (/nix/store is world-readable).
  # If yubikey-identity.txt is tracked in the repository, automatically copy it to /var/lib/sops-nix/key.txt
  # before setupSecrets runs, so clean installations work without manual key copying.
  system.activationScripts = lib.mkIf hasRepoIdentity {
    sopsInitAgeKey = {
      deps = [ "specialfs" ];
      text = ''
        mkdir -p /var/lib/sops-nix
        if [ ! -f /var/lib/sops-nix/key.txt ] || [ "${repoIdentityFile}" -nt /var/lib/sops-nix/key.txt ]; then
          cp -f ${repoIdentityFile} /var/lib/sops-nix/key.txt
          chmod 600 /var/lib/sops-nix/key.txt
        fi
      '';
    };
    setupSecrets.deps = [ "sopsInitAgeKey" ];
  };

  systemd.tmpfiles.rules = lib.mkIf hasRepoIdentity [
    "C /var/lib/sops-nix/key.txt 0600 root root - ${repoIdentityFile}"
  ];
}
