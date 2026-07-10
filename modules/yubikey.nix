{ config, pkgs, ... }:

{
  services.udev.packages = [ pkgs.yubikey-personalization ];
  services.pcscd.enable = true; 

  environment.systemPackages = with pkgs; [
    yubikey-manager
    yubikey-personalization
    yubioath-flutter
  ];
  
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="1050", MODE="0660", GROUP="plugdev"
  '';
}
