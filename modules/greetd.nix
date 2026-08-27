{ config, pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.tuigreet
    pkgs.greetd
  ];

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks --cmd 'uwsm start -- hyprland-uwsm.desktop'";
        user = "greeter";
      };
    };
  };
}
