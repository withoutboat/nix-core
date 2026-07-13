{ config, lib, pkgs, spec ? { }, ... }:

let
  managedUsers = lib.attrNames config.home-manager.users;
  managedUserCount = builtins.length managedUsers;
  username =
    if spec ? username then
      spec.username
    else if managedUserCount == 1 then
      lib.head managedUsers
    else
      "";
in {
  assertions = [
    {
      assertion = username != "";
      message = "modules/greetd.nix requires spec.username or exactly one home-manager.users entry for Hyprland auto-start; found ${toString managedUserCount}.";
    }
  ];

  services.greetd = {
    enable = true;
    settings = {
      # Auto-start Hyprland on this workstation; tuigreet remains available as a fallback session chooser.
      initial_session = {
        command = "Hyprland";
        user = username;
      };

      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --remember-user --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };
}
