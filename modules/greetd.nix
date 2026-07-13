{ config, lib, pkgs, spec ? { }, ... }:

let
  normalUsers = lib.attrNames (lib.filterAttrs (_: user: user.isNormalUser or false) config.users.users);
  username =
    if spec ? username then
      spec.username
    else if normalUsers != [ ] then
      lib.head normalUsers
    else
      "";
in {
  assertions = [
    {
      assertion = normalUsers != [ ] || spec ? username;
      message = "modules/greetd.nix needs a normal user or spec.username for Hyprland auto-start.";
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
