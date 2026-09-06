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

    bypassEnable = lib.mkOption {
      type = lib.types.bool;
      default = spec.amneziaBypassEnable or true;
      description = "Enable DNS-based domain bypassing of AmneziaWG for direct internet access to specified domains.";
    };

    bypassDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = spec.amneziaBypassDomains or [
        "github.com"
        "githubusercontent.com"
        "githubassets.com"
        "github.io"
        "nixos.org"
        "cachix.org"
        "flakehub.com"
        "garnix.io"
        "gitlab.com"
        "codeberg.org"
        "crates.io"
      ];
      description = "Domain suffixes to route directly via default gateway in bypass of AmneziaWG.";
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
        after = [ "network.target" "network-online.target" "firewall.service" ]
          ++ lib.optional (config ? sops && config.sops.useSystemdActivation) "sops-install-secrets.service"
          ++ lib.optional config.networking.networkmanager.enable "NetworkManager-wait-online.service";
        wants = [ "network-online.target" "firewall.service" ]
          ++ lib.optional (config ? sops && config.sops.useSystemdActivation) "sops-install-secrets.service"
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
          pkgs.ipset
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

    (lib.mkIf (cfg.enable && cfg.bypassEnable && cfg.bypassDomains != [ ]) {
      environment.systemPackages = [
        pkgs.ipset
      ];

      boot.kernelModules = [
        "ip_set"
        "ip_set_hash_ip"
        "xt_set"
      ];

      boot.kernel.sysctl = {
        "net.ipv4.conf.default.rp_filter" = lib.mkDefault 2;
        "net.ipv4.conf.all.rp_filter" = lib.mkDefault 2;
      };

      networking.firewall.extraCommands = lib.mkAfter ''
        ${pkgs.ipset}/bin/ipset create -exist awg_bypass_v4 hash:ip timeout 3600
        ${pkgs.ipset}/bin/ipset create -exist awg_bypass_v6 hash:ip family inet6 timeout 3600
        iptables -t mangle -C OUTPUT -m set --match-set awg_bypass_v4 dst -j MARK --set-mark 51820 2>/dev/null || \
          iptables -t mangle -A OUTPUT -m set --match-set awg_bypass_v4 dst -j MARK --set-mark 51820
        ip6tables -t mangle -C OUTPUT -m set --match-set awg_bypass_v6 dst -j MARK --set-mark 51820 2>/dev/null || \
          ip6tables -t mangle -A OUTPUT -m set --match-set awg_bypass_v6 dst -j MARK --set-mark 51820
      '';

      networking.firewall.extraStopCommands = lib.mkAfter ''
        iptables -t mangle -D OUTPUT -m set --match-set awg_bypass_v4 dst -j MARK --set-mark 51820 2>/dev/null || true
        ip6tables -t mangle -D OUTPUT -m set --match-set awg_bypass_v6 dst -j MARK --set-mark 51820 2>/dev/null || true
      '';

      services.dnsmasq = {
        enable = true;
        resolveLocalQueries = true;
        settings = {
          server = [ "1.1.1.1" "1.0.0.1" ];
          ipset = map (domain: "/${domain}/awg_bypass_v4,awg_bypass_v6") cfg.bypassDomains;
        };
      };

      systemd.services.dnsmasq = {
        after = [ "firewall.service" ];
        wants = [ "firewall.service" ];
        serviceConfig = {
          AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_NET_BIND_SERVICE" ];
          CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_NET_BIND_SERVICE" ];
        };
      };
    })
  ];
}
