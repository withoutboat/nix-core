{ config, pkgs, ... }:

{
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  environment.systemPackages = with pkgs; [
    solaar
  ];

  services.udev.packages = [ pkgs.solaar ];
}
