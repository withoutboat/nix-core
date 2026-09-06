{ config, pkgs, ... }:

{
  users.groups.plugdev = {};

  security.pam.u2f = {
    enable = true;
    control = "sufficient";
    settings = {
      authFile = "/etc/u2f_mappings";
      cue = true;
      control = "sufficient";
    };
  };

  security.pam.services.sudo.u2fAuth = true;
  security.pam.services.login.u2fAuth = true;
  security.pam.services.greetd = {
    enableGnomeKeyring = true;
    u2fAuth = true;
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

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="1050", MODE="0660", GROUP="plugdev"
  '';
}
