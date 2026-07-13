{ config, lib, pkgs, spec ? { }, ... }:

let
  managedUsers = lib.attrNames config.home-manager.users;
  managedUserCount = builtins.length managedUsers;
  managedUserList = lib.concatStringsSep ", " managedUsers;
  hasExplicitUsername = spec ? username;
  hasManagedUser = managedUserCount == 1;
  username =
    if hasExplicitUsername then
      spec.username
    else if hasManagedUser then
      lib.head managedUsers
    else
      null;
  usernameAssertionMessage =
    if managedUserCount == 0 then
      "modules/greetd.nix requires spec.username or exactly one home-manager.users entry for Hyprland auto-start. No Home Manager users are configured, and spec.username is not set."
    else
      "modules/greetd.nix requires spec.username or exactly one home-manager.users entry for Hyprland auto-start. Found ${toString managedUserCount} managed users (${managedUserList}), so set spec.username explicitly.";
in {
  assertions = [
    {
      assertion = username != null;
      message = usernameAssertionMessage;
    }
  ];

  services.greetd = {
    enable = true;
    settings = {
      # Auto-start Hyprland on this workstation; tuigreet remains available as a fallback session chooser.
      initial_session = {
        command = "${pkgs.hyprland}/bin/Hyprland";
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
