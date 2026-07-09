{ config, pkgs, ... }:

{
  services.udev.packages = [ pkgs.yubikey-personalization ];

  services.pcscd.enable = true; 

  environment.systemPackages = with pkgs; [
    yubikey-manager
    yubikey-personalization
    yubioath-flutter # GUI для OTP кодов (если нужно)
  ];

}
