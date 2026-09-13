{ config, pkgs, ... }:

{
  # Vial keyboard udev rules for raw HID device access (/dev/hidraw*)
  # Matches all Vial firmware devices by serial number pattern or vendor/product ID
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="55d4", ATTRS{idProduct}=="0461", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
  '';
}
