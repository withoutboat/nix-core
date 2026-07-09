{ pkgs, ... }:

{
  # Enable Hyprland compositor
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Hyprland-specific environment variables for better compatibility
  environment.sessionVariables = {
    # Hint to Electron apps to use Wayland
    NIXOS_OZONE_WL = "1";
  };
}
