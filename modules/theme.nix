{ config, pkgs, lib, ... }:

let
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
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    # Catppuccin Mocha Waves wallpaper (community mirror of catppuccin/wallpapers)
    image = pkgs.fetchurl {
      name = "catppuccin-mocha-waves.jpg";
      url = "https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/waves/Waves%20Dark%206016x6016.jpg";
      sha256 = "1a8e42ab67483980c79674e6b614990630ec4d176691e94e25ae5e6ff2c45d88";
    };

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

  # Propagate base color options to Home Manager for Zellij default theme and other components
  home-manager.sharedModules = [
    ({ config, lib, ... }:
      let
        hmColors =
          if config ? lib.stylix && config.lib.stylix ? colors then
            mkBaseColors config.lib.stylix.colors.withHashtag
          else
            baseColors;
      in
      {
        lib.stylix.baseColors = hmColors;

        programs.zellij = {
          settings.theme = lib.mkDefault "default";
          themes.stylix.themes.default = lib.mapAttrs (_: lib.mkDefault) hmColors;
        };
      })
  ];

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
