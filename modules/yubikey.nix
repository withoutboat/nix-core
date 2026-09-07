{ config, pkgs, lib, ... }:

let
  repoU2fFile = ../secrets/u2f_mappings;
  hasRepoU2fMappings = builtins.pathExists repoU2fFile;
in
{
  users.groups.plugdev = {};

  # Declaratively symlink u2f_mappings from repo to /etc if present
  environment.etc = lib.mkIf hasRepoU2fMappings {
    "u2f_mappings" = {
      source = repoU2fFile;
      mode = "0644";
    };
  };

  security.pam.u2f = {
    enable = true;
    control = "sufficient";
    settings = {
      origin = "pam://${config.networking.hostName}";
      appid = "pam://${config.networking.hostName}";
      authfile = "/etc/u2f_mappings";
      cue = true;
      nouserok = true;
    };
  };

  security.pam.services = {
    sudo.u2fAuth = true;
    login.u2fAuth = true;
    greetd = {
      enableGnomeKeyring = true;
      u2fAuth = true;
    };
    polkit-1.u2fAuth = true;
  };

  services.udev.packages = [
    pkgs.yubikey-personalization
    pkgs.libfido2
  ];

  services.pcscd = {
    enable = true;
    plugins = [ pkgs.ccid ];
  };

  # Disable internal CCID in scdaemon so GnuPG shares the smartcard via pcscd
  programs.gnupg.agent.settings = {
    disable-ccid = true;
  }; 

  environment.systemPackages = with pkgs; [
    pam_u2f
    yubikey-manager
    yubioath-flutter
    libfido2
  ];
  
  users.users.pcscd.extraGroups = [ "plugdev" ];
  users.users.greeter.extraGroups = [ "plugdev" ];

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="1050", MODE="0660", GROUP="plugdev"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1050", MODE="0660", GROUP="plugdev"
  '';
}
