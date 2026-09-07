{ config, pkgs, lib, inputs, ... }:

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

  # Integrate sops-nix into Home Manager
  home-manager.sharedModules = [
    inputs.sops-nix.homeManagerModules.sops
    ({ config, ... }: {
      sops.age = {
        plugins = [ pkgs.age-plugin-yubikey ];
        keyFile = lib.mkDefault (
          if hasRepoIdentity then
            "/etc/sops/age/keys.txt"
          else
            "${config.home.homeDirectory}/.config/sops/age/keys.txt"
        );
      };
    })
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

  # Ensure pcscd and /etc symlinks are available before sops decrypts secrets
  system.activationScripts = lib.mkIf (hasRepoIdentity && config.sops.secrets != { }) {
    setupYubikeyForSops = lib.stringAfter [ "etc" "specialfs" ] ''
      if ! ${pkgs.procps}/bin/pgrep -x pcscd >/dev/null 2>&1; then
        echo "Starting temporary pcscd for sops-nix secret decryption..."
        mkdir -p /var/lib/pcsc
        ln -sfn ${pkgs.ccid}/pcsc/drivers /var/lib/pcsc/drivers
        mkdir -p /run/pcscd
        rm -f /run/pcscd/pcscd.comm /run/pcscd/pcscd.pid
        EXTRA_ARGS=""
        if [ -f /etc/reader.conf ]; then
          EXTRA_ARGS="-c /etc/reader.conf"
        fi
        PCSCLITE_HP_DROPDIR="${pkgs.ccid}/pcsc/drivers" ${pkgs.pcsclite}/bin/pcscd $EXTRA_ARGS
        touch /run/pcscd-started-by-activation
        for i in $(seq 1 30); do
          if [ -S /run/pcscd/pcscd.comm ]; then
            sleep 0.5
            break
          fi
          sleep 0.1
        done
      fi
    '';

    setupSecrets.deps = [ "etc" "setupYubikeyForSops" ];

    cleanupYubikeyForSops = lib.stringAfter [ "setupSecrets" ] ''
      if [ -f /run/pcscd-started-by-activation ]; then
        echo "Stopping temporary pcscd..."
        rm -f /run/pcscd-started-by-activation
        ${pkgs.procps}/bin/pkill -x pcscd || true
        for i in $(seq 1 20); do
          if ! ${pkgs.procps}/bin/pgrep -x pcscd >/dev/null 2>&1; then
            break
          fi
          sleep 0.1
        done
        rm -f /run/pcscd/pcscd.comm /run/pcscd/pcscd.pid || true
      fi
    '';
  };
}
