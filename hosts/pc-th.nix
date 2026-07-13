{ config, pkgs, ... }:

{
  imports = [
    ../modules/greetd.nix
    ../modules/user.nix
    ../modules/hardware-drivers.nix
    ../modules/networks.nix
    ../modules/yubikey.nix
    ../modules/logitech.nix
    ../modules/terminal.nix
    ../modules/hyperland.nix
    ../modules/wayland.nix
  ];

  networking.hostName = "pc-th";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Tyumen";
  i18n.defaultLocale = "en_US.UTF-8";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.efiSysMountPoint = "/efi";
  boot.loader.systemd-boot.configurationLimit = 15;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd = {
    systemd.enable = true; 
    availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" "usbhid" "hid_generic" ];
    luks.devices."cryptroot" = pkgs.lib.mkForce {
      device = "/dev/disk/by-partlabel/disk-main-luks";
      preLVM = true;
      crypttabExtraOpts = [ "fido2-device=auto" "fido2-with-user-presence=yes" ];
    };
  }; 
  
  environment.systemPackages = with pkgs; [
    git neovim curl home-manager
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "26.11";
}
