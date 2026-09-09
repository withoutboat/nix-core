{ config, pkgs, lib, ... }:

let
  # Default system themes for console, greetd, and base system
  defaultThemes = {
    default_dark = {
      name = "default_dark";
      polarity = "dark";
      base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
      image = pkgs.fetchurl {
        name = "catppuccin-mocha-waves.jpg";
        url = "https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/waves/Waves%20Dark%206016x6016.jpg";
        sha256 = "1a8e42ab67483980c79674e6b614990630ec4d176691e94e25ae5e6ff2c45d88";
      };
    };

    default_light = {
      name = "default_light";
      polarity = "light";
      base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-latte.yaml";
      image = pkgs.fetchurl {
        name = "catppuccin-latte-waves.jpg";
        url = "https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/waves/Waves%20Light%206016x6016.jpg";
        sha256 = "6ab30f280e6c09a7e2df0df288c01b0f8a5ac1a70f3f65767a776963c9ced8ed";
      };
    };
  };

  # Derive base color mapping from active Stylix palette (base16)
  mkBaseColors = c: {
    fg = c.base05;
    bg = c.base00;
    black = c.base01;
    red = c.base08;
    green = c.base0B;
    yellow = c.base0A;
    blue = c.base0D;
    magenta = c.base0E;
    cyan = c.base0C;
    white = c.base06;
    orange = c.base09;
  };

  baseColors = mkBaseColors config.lib.stylix.colors.withHashtag;
in
{
  # Expose base colors in config.lib.stylix for NixOS modules
  lib.stylix.baseColors = baseColors;

  stylix = {
    enable = true;
    polarity = defaultThemes.default_dark.polarity;
    base16Scheme = defaultThemes.default_dark.base16Scheme;
    image = defaultThemes.default_dark.image;

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.blex-mono;
        name = "BlexMono Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.ibm-plex;
        name = "IBM Plex Sans";
      };
      serif = {
        package = pkgs.ibm-plex;
        name = "IBM Plex Serif";
      };
      sizes = {
        terminal = 12;
        applications = 11;
        desktop = 10;
        popups = 10;
      };
    };
  };

  specialisation.light.configuration = {
    stylix = {
      polarity = lib.mkForce defaultThemes.default_light.polarity;
      base16Scheme = lib.mkForce defaultThemes.default_light.base16Scheme;
      image = lib.mkForce defaultThemes.default_light.image;
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
