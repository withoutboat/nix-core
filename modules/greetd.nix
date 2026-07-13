{ config, pkgs, ... }:

{
  services.greetd = {
    enable = true;
    package = pkgs.greetd.tuigreet;

    settings = {
      default_session = {
        command = "tuigreet --time --remember --remember-user --cmd Hyprland";
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
