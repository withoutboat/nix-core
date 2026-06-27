{ config, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/profiles/installation-device.nix"
    
    ../modules/security.nix
  ];

  networking.hostName = "nixos-core-installer";
  networking.networkmanager.enable = true;

  environment.systemPackages = with pkgs; [
    git
    yubikey-manager
    cryptsetup
    zfs
    parted
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
