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
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks --cmd 'dbus-run-session Hyprland'";
        user = "greeter";
      };
    };
  };

  security.pam.services.greetd = {
    text = ''
      auth     required pam_securetty.so
      auth     requisite pam_nologin.so
      auth     required pam_u2f.so authfile=/etc/u2f_mappings cue
      auth     required pam_unix.so nullok
      account  include  login
      password include  login
      session  include  login
    '';
  };
}
