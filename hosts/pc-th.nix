{ config, pkgs, ... }:

{
  imports = [
    ../modules/user.nix
    ../modules/hardware-drivers.nix
    ../modules/yubikey.nix
    ../modules/logitech.nix
    ../modules/terminal.nix
    ../modules/hyperland.nix
    ../modules/wayland.nix
  ];

  networking.hostName = "pc-th";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Tyumen";
  i18n.defaultLocale = "ru_RU.UTF-8";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.efiSysMountPoint = "/efi";
  boot.loader.systemd-boot.configurationLimit = 15;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.u2f.enable = true;

  security.pam.u2f = {
    enable = true;
    control = "sufficient";
    authFile = "/etc/u2f_mappings";
  };

  security.pam.services.sudo.u2fAuth = true;
  security.pam.services.login.u2fAuth = true;

  boot.initrd = {
    systemd.enable = true; 
    availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
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
