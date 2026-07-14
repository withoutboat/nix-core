{ pkgs, inputs, ... }:

{
  # Hyprland-specific environment variables for better compatibility
  environment.sessionVariables = {
    # Hint to Electron apps to use Wayland
    NIXOS_OZONE_WL = "1";
  };

  programs.hyprland = {
    enable = true;
   # package = inputs.hyprland.packages.${pkgs.system}.hyprland;
   # portalPackage = inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
   # xwayland.enable = true;
  };
}
