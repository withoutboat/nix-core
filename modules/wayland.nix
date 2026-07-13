{ pkgs, ... }:

{
  # Essential Wayland utilities and infrastructure
  environment.systemPackages = with pkgs; [
    hyprpaper     # Wallpaper daemon
    hyprlock      # Screen locker
    hypridle      # Idle management
    waybar        # Status bar
    wofi          # Application launcher
    mako          # Notification daemon
    wl-clipboard  # Clipboard management
    grim          # Screenshot tool
    slurp         # Region selector
    brightnessctl # Hardware control
    playerctl     # Media control
  ];

  # Security, Portals, and Keyring integration
  security.polkit.enable = true;
  programs.dconf.enable = true;
  services.gnome.gnome-keyring.enable = true;
  
  xdg.portal = {
    enable = true;
    config.common.default = "*";
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };
}
