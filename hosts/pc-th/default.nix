{ pkgs, lib, ... }:

let
  generatedConfiguration = ./configuration.nix;
  generatedHardware = ./hardware.nix;
  hasGeneratedConfiguration = builtins.pathExists generatedConfiguration;
  hasGeneratedHardware = builtins.pathExists generatedHardware;
in
{
  imports = [
    ../../modules/greetd.nix
    ../../modules/user.nix
    ../../modules/hardware-drivers.nix
    ../../modules/networks.nix
    ../../modules/amneziawg.nix
    ../../modules/yubikey.nix
    ../../modules/logitech.nix
    ../../modules/terminal.nix
    ../../modules/hyperland.nix
    ../../modules/sops.nix
    ../../modules/theme.nix
    ../../modules/system.nix
  ]
  ++ lib.optional hasGeneratedConfiguration generatedConfiguration
  ++ lib.optional hasGeneratedHardware generatedHardware;

  assertions = lib.optional (hasGeneratedConfiguration && !hasGeneratedHardware) {
    assertion = false;
    message = ''
      hosts/pc-th/hardware.nix is required once hosts/pc-th/configuration.nix has been generated.
      Run nixos-bootstrapper again so it writes both files before using nixos-install --flake .#pc-th.
    '';
  };

  networking.hostName = "pc-th";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Yekaterinburg";
  services.timesyncd.enable = true;
  i18n.defaultLocale = "en_US.UTF-8";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.efiSysMountPoint = "/efi";
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.systemd-boot.editor = false;

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
    git curl home-manager
  ];

  system.stateVersion = "26.11";
}
