{ pkgs, inputs, ... }:

{
  # Hyprland-specific environment variables for better compatibility
  environment.sessionVariables = {
    # Hint to Electron apps to use Wayland
    NIXOS_OZONE_WL = "1";
  };

  programs.hyprland = {
    enable = true;
  };
  security.polkit.enable = true;
  programs.dconf.enable = true;
  services.gnome.gnome-keyring.enable = true;
}
