{ config, pkgs, lib, inputs ? { }, ... }:

let
  # Primary username: find from home-manager users or fallback to "withoutboat"
  primaryUser = let
    hmUsers = builtins.attrNames (config.home-manager.users or { });
  in if hmUsers != [ ] then builtins.head hmUsers else "withoutboat";

  # Default themes catalog fallback
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

    solarized_light = {
      name = "solarized_light";
      polarity = "light";
      base16Scheme = "${pkgs.base16-schemes}/share/themes/solarized-light.yaml";
      image = pkgs.fetchurl {
        name = "catppuccin-latte-waves.jpg";
        url = "https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/waves/Waves%20Light%206016x6016.jpg";
        sha256 = "6ab30f280e6c09a7e2df0df288c01b0f8a5ac1a70f3f65767a776963c9ced8ed";
      };
    };

    solarized_dark = {
      name = "solarized_dark";
      polarity = "dark";
      base16Scheme = "${pkgs.base16-schemes}/share/themes/solarized-dark.yaml";
      image = pkgs.fetchurl {
        name = "catppuccin-mocha-waves.jpg";
        url = "https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/waves/Waves%20Dark%206016x6016.jpg";
        sha256 = "1a8e42ab67483980c79674e6b614990630ec4d176691e94e25ae5e6ff2c45d88";
      };
    };

    tokyo_night_dark = {
      name = "tokyo_night_dark";
      polarity = "dark";
      base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-dark.yaml";
      image = pkgs.fetchurl {
        name = "catppuccin-mocha-waves.jpg";
        url = "https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/waves/Waves%20Dark%206016x6016.jpg";
        sha256 = "1a8e42ab67483980c79674e6b614990630ec4d176691e94e25ae5e6ff2c45d88";
      };
    };
  };

  normalizeThemeName = name: {
    "solirized_light" = "solarized_light";
    "solorized_light" = "solarized_light";
    "solarized_light" = "solarized_light";
    "solorized_dark" = "solarized_dark";
    "solarized_dark" = "solarized_dark";
    "tokio_nigth_dark" = "tokyo_night_dark";
    "tokyo_night_dark" = "tokyo_night_dark";
    "tokyo_night" = "tokyo_night_dark";
    "default_dark" = "default_dark";
    "default_light" = "default_light";
  }.${name} or name;

  resolveTheme = name:
    if inputs ? nix-home && inputs.nix-home ? resolveTheme then
      inputs.nix-home.resolveTheme pkgs name
    else
      defaultThemes.${normalizeThemeName name} or defaultThemes.default_dark;

  # Read user theme config from nix-home
  userConfig =
    if inputs ? nix-home && inputs.nix-home ? getUserConfig then
      inputs.nix-home.getUserConfig primaryUser
    else if inputs ? nix-home && builtins.pathExists (inputs.nix-home + "/configs/${primaryUser}.nix") then
      import (inputs.nix-home + "/configs/${primaryUser}.nix")
    else
      {
        lightTheme = "default_light";
        darkTheme = "default_dark";
      };

  darkTheme = resolveTheme (userConfig.darkTheme or "default_dark");
  lightTheme = resolveTheme (userConfig.lightTheme or "default_light");

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
    polarity = darkTheme.polarity;
    base16Scheme = darkTheme.base16Scheme;
    image = darkTheme.image;

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
      polarity = lib.mkForce lightTheme.polarity;
      base16Scheme = lib.mkForce lightTheme.base16Scheme;
      image = lib.mkForce lightTheme.image;
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
