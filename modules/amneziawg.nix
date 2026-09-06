{ config, lib, pkgs, ... }:

let
  cfg = config.services.amneziawg;
  kernel = config.boot.kernelPackages;
in
{
  options.services.amneziawg = {
    enable = lib.mkEnableOption "AmneziaWG interface via awg-quick";

    interfaceName = lib.mkOption {
      type = lib.types.str;
      default = "awg0";
      description = "AmneziaWG interface name (must be <= 15 chars).";
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
      default = null;
      description = "Path to AmneziaWG configuration file.";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to start interface at boot.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.extraModulePackages = [
      kernel.amneziawg
    ];

    boot.kernelModules = [
      "amneziawg"
    ];

    environment.systemPackages = [
      pkgs.amneziawg-tools
      pkgs.amneziawg-go
    ];

    assertions = [
      {
        assertion = cfg.configFile != null;
        message =
          "services.amneziawg.configFile must be set when AmneziaWG is enabled.";
      }
    ];

    systemd.services."awg-quick-${cfg.interfaceName}" = {
      description = "AmneziaWG Tunnel - ${cfg.interfaceName}";
      after = [ "network.target" "network-online.target" ]
        ++ lib.optional config.networking.networkmanager.enable "NetworkManager-wait-online.service";
      wants = [ "network-online.target" ]
        ++ lib.optional config.networking.networkmanager.enable "NetworkManager-wait-online.service";
      wantedBy = lib.optional cfg.autoStart "multi-user.target";
      aliases = [ "wg-quick-${cfg.interfaceName}.service" ];

      environment.DEVICE = cfg.interfaceName;

      path = [
        pkgs.amneziawg-tools
        pkgs.amneziawg-go
        pkgs.kmod
        pkgs.iproute2
        pkgs.procps
        pkgs.coreutils
        config.networking.firewall.package
        config.networking.resolvconf.package
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "amneziawg";
        RuntimeDirectoryMode = "0700";
      };

      script = ''
        modprobe amneziawg || true
        cp ${cfg.configFile} /run/amneziawg/${cfg.interfaceName}.conf
        chmod 600 /run/amneziawg/${cfg.interfaceName}.conf
        awg-quick up /run/amneziawg/${cfg.interfaceName}.conf
      '';

      preStop = ''
        if [ ! -f /run/amneziawg/${cfg.interfaceName}.conf ]; then
          cp ${cfg.configFile} /run/amneziawg/${cfg.interfaceName}.conf
          chmod 600 /run/amneziawg/${cfg.interfaceName}.conf
        fi
        awg-quick down /run/amneziawg/${cfg.interfaceName}.conf
      '';
    };

    networking.networkmanager.unmanaged = lib.mkIf config.networking.networkmanager.enable [
      "interface-name:${cfg.interfaceName}"
    ];
  };
}
