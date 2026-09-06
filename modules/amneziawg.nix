{ config, lib, pkgs, options, spec ? {}, ... }:

let
  cfg = config.services.amneziawg;
  kernel = config.boot.kernelPackages;

  amneziaConfigFile = spec.amneziaConfig or null;
  hasAmneziaConfigSpec = (spec ? amneziaConfig) && amneziaConfigFile != null && amneziaConfigFile != "";
  rawFileName = if hasAmneziaConfigSpec then baseNameOf amneziaConfigFile else null;
  secretPath = if hasAmneziaConfigSpec then ../secrets + "/${rawFileName}" else null;
  hasSecretFile = hasAmneziaConfigSpec && builtins.pathExists secretPath;
in
{
  options.services.amneziawg = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = hasSecretFile;
      description = "Enable AmneziaWG interface via awg-quick.";
    };

    interfaceName = lib.mkOption {
      type = lib.types.str;
      default = "awg0";
      description = "AmneziaWG interface name (must be <= 15 chars).";
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
      default = if hasSecretFile && (options ? sops) then config.sops.secrets.${rawFileName}.path else null;
      description = "Path to AmneziaWG configuration file.";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to start interface at boot.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (hasSecretFile && (options ? sops)) {
      sops.secrets.${rawFileName} = {
        format = "binary";
        sopsFile = secretPath;
        mode = "0400";
        owner = "root";
      };
    })

    (lib.mkIf cfg.enable {
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
          ++ lib.optional (config ? sops) "sops-nix.service"
          ++ lib.optional config.networking.networkmanager.enable "NetworkManager-wait-online.service";
        wants = [ "network-online.target" ]
          ++ lib.optional (config ? sops) "sops-nix.service"
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

        # Do not fail or block nixos-rebuild switch if tunnel cannot be established
        unitConfig.DefaultDependencies = true;

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = "amneziawg";
          RuntimeDirectoryMode = "0700";
          SuccessExitStatus = "0 1";
        };

        script = ''
          modprobe amneziawg || true
          if [ ! -f "${cfg.configFile}" ]; then
            echo "AmneziaWG config file '${cfg.configFile}' not found. Skipping interface setup."
            exit 0
          fi
          cp "${cfg.configFile}" /run/amneziawg/${cfg.interfaceName}.conf
          chmod 600 /run/amneziawg/${cfg.interfaceName}.conf
          awg-quick up /run/amneziawg/${cfg.interfaceName}.conf || true
        '';

        preStop = ''
          if [ ! -f /run/amneziawg/${cfg.interfaceName}.conf ]; then
            if [ -f "${cfg.configFile}" ]; then
              cp "${cfg.configFile}" /run/amneziawg/${cfg.interfaceName}.conf
              chmod 600 /run/amneziawg/${cfg.interfaceName}.conf
            fi
          fi
          if [ -f /run/amneziawg/${cfg.interfaceName}.conf ]; then
            awg-quick down /run/amneziawg/${cfg.interfaceName}.conf || true
          fi
        '';
      };

      networking.networkmanager.unmanaged = lib.mkIf config.networking.networkmanager.enable [
        "interface-name:${cfg.interfaceName}"
      ];
    })
  ];
}
