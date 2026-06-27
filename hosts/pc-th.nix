{ config, pkgs, lib, ... }:

{
  imports = [
    (lib.optional (builtins.pathExists ./pc-th-hardware.nix) ./pc-th-hardware.nix)
  ];

  networking.hostName = "pc-th";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Tyumen";
  i18n.defaultLocale = "ru_RU.UTF-8";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd = {
    availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
    luks.yubikeySupport = true;
    luks.devices."cryptroot" = {
      device = "/dev/disk/by-partlabel/disk-main-luks"; 
      preLVM = true;
      yubikey.slot = 2;
    };
  };

  users.users.vladimir = {
    isNormalUser = true;
    description = "Vladimir";
    extraGroups = [ "networkmanager" "wheel" "video" "audio" ];
    shell = pkgs.zsh;
  };

  environment.systemPackages = with pkgs; [
    git neovim curl yubikey-manager home-manager
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "26.11";
}
