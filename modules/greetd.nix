{ config, lib, pkgs, spec ? { }, ... }:

let
  managedUsers = lib.attrNames config.home-manager.users;
  username =
    if spec ? username then
      spec.username
    else if builtins.length managedUsers == 1 then
      lib.head managedUsers
    else
      "";
in {
  assertions = [
    {
      assertion = username != "";
      message = "modules/greetd.nix needs spec.username or exactly one home-manager.users entry for Hyprland auto-start.";
    }
  ];

  services.greetd = {
    enable = true;
    settings = {
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
