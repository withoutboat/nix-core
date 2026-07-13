{ config, pkgs, ... }:

{
  users.groups.plugdev = {};

  security.pam.u2f = {
    enable = true;
    control = "sufficient";
    settings = {
      authFile = "/etc/u2f_mappings";
      cue = true;
    };
  };

  security.pam.services.sudo.u2fAuth = true;
  security.pam.services.login.u2fAuth = true;
  security.pam.services.greetd.u2fAuth = true;

  services.udev.packages = [ pkgs.yubikey-personalization ];
  services.pcscd.enable = true; 

  environment.systemPackages = with pkgs; [
    pam_u2f
    yubikey-manager
    yubioath-flutter
  ];
  
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="1050", MODE="0660", GROUP="plugdev"
  '';
}
