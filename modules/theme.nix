{ pkgs, lib, ... }:

{
  stylix = {
    enable = true;
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    # Catppuccin Mocha Waves wallpaper (community mirror of catppuccin/wallpapers)
    image = pkgs.fetchurl {
      name = "catppuccin-mocha-waves.jpg";
      url = "https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/waves/Waves%20Dark%206016x6016.jpg";
      sha256 = "1a8e42ab67483980c79674e6b614990630ec4d176691e94e25ae5e6ff2c45d88";
    };
  };

  specialisation.light.configuration = {
    stylix = {
      polarity = lib.mkForce "light";
      base16Scheme = lib.mkForce "${pkgs.base16-schemes}/share/themes/catppuccin-latte.yaml";
      # Catppuccin Latte Waves wallpaper (community mirror of catppuccin/wallpapers)
      image = lib.mkForce (pkgs.fetchurl {
        name = "catppuccin-latte-waves.jpg";
        url = "https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/waves/Waves%20Light%206016x6016.jpg";
        sha256 = "6ab30f280e6c09a7e2df0df288c01b0f8a5ac1a70f3f65767a776963c9ced8ed";
      });
    };
  };

  # Allow wheel group to switch system specialisations without password
  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands = [
        {
          command = "/run/current-system/specialisation/*/bin/switch-to-configuration test";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/specialisation/light/bin/switch-to-configuration test";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/bin/switch-to-configuration test";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
