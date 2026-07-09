{ config, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/profiles/installation-device.nix"
    
    ../modules/security.nix
  ];

  networking.hostName = "nixos-core-installer";
  networking.networkmanager.enable = true;

  services.resolved.enable = true;

  environment.systemPackages = with pkgs; [
    git
    yubikey-manager
    cryptsetup
    zfs
    parted             # partprobe
    gptfdisk           # sgdisk
    dosfstools         # mkfs.fat (boot раздел)
    e2fsprogs          # mkfs.ext4 (root раздел)
    pciutils           # lspci (детекция GPU в скрипте)
    nixos-bootstrapper 
  ];

  services.getty.autologinUser = pkgs.lib.mkForce "root";
  
  programs.bash.loginShellInit = ''
    if [ "$(tty)" = "/dev/tty1" ]; then
      exec nixos-bootstrapper
    fi
  '';

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
