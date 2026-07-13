{ config, pkgs, ... }:

let
  hyprlandSession = pkgs.writeShellScriptBin "hyprland-session" ''
    exec ${pkgs.dbus}/bin/dbus-run-session ${pkgs.hyprland}/bin/Hyprland
  '';
in
{
  environment.systemPackages = [
    pkgs.tuigreet
    hyprlandSession
  ];

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user --cmd ${hyprlandSession}/bin/hyprland-session";
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
