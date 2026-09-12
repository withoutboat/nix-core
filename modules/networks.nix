{ config, lib, pkgs, spec ? {}, ... }:

let
  hasWifi = (spec ? wifiSSID) && (spec ? wifiPass)
    && spec.wifiSSID != "" && spec.wifiPass != "";

  bypassCfg = config.networking.bypass;

  v4Dns = builtins.filter (s: !lib.hasInfix ":" s) bypassCfg.dnsServers;
  v6Dns = builtins.filter (s: lib.hasInfix ":" s) bypassCfg.dnsServers;

  nftBypassCommands = ''
    ${pkgs.nftables}/bin/nft 'add table inet ${bypassCfg.nftablesTable}'
    ${pkgs.nftables}/bin/nft 'list set inet ${bypassCfg.nftablesTable} bypass_v4' >/dev/null 2>&1 || \
      ${pkgs.nftables}/bin/nft 'add set inet ${bypassCfg.nftablesTable} bypass_v4 { type ipv4_addr; flags timeout; timeout 1h; }'
    ${pkgs.nftables}/bin/nft 'list set inet ${bypassCfg.nftablesTable} bypass_v6' >/dev/null 2>&1 || \
      ${pkgs.nftables}/bin/nft 'add set inet ${bypassCfg.nftablesTable} bypass_v6 { type ipv6_addr; flags timeout; timeout 1h; }'
    ${pkgs.nftables}/bin/nft 'add chain inet ${bypassCfg.nftablesTable} output { type route hook output priority mangle; policy accept; }'
    ${pkgs.nftables}/bin/nft 'flush chain inet ${bypassCfg.nftablesTable} output'
    ${lib.optionalString (v4Dns != [ ]) ''
      ${pkgs.nftables}/bin/nft 'add rule inet ${bypassCfg.nftablesTable} output ip daddr { ${lib.concatStringsSep ", " v4Dns} } counter meta mark set ${toString bypassCfg.mark}'
    ''}
    ${lib.optionalString (v6Dns != [ ]) ''
      ${pkgs.nftables}/bin/nft 'add rule inet ${bypassCfg.nftablesTable} output ip6 daddr { ${lib.concatStringsSep ", " v6Dns} } counter meta mark set ${toString bypassCfg.mark}'
    ''}
    ${pkgs.nftables}/bin/nft 'add rule inet ${bypassCfg.nftablesTable} output ip daddr @bypass_v4 counter meta mark set ${toString bypassCfg.mark}'
    ${pkgs.nftables}/bin/nft 'add rule inet ${bypassCfg.nftablesTable} output ip6 daddr @bypass_v6 counter meta mark set ${toString bypassCfg.mark}'
    ${pkgs.nftables}/bin/nft 'add chain inet ${bypassCfg.nftablesTable} postrouting { type nat hook postrouting priority srcnat; policy accept; }'
    ${pkgs.nftables}/bin/nft 'flush chain inet ${bypassCfg.nftablesTable} postrouting'
    ${lib.optionalString (v4Dns != [ ]) ''
      ${pkgs.nftables}/bin/nft 'add rule inet ${bypassCfg.nftablesTable} postrouting ip daddr { ${lib.concatStringsSep ", " v4Dns} } counter masquerade'
    ''}
    ${lib.optionalString (v6Dns != [ ]) ''
      ${pkgs.nftables}/bin/nft 'add rule inet ${bypassCfg.nftablesTable} postrouting ip6 daddr { ${lib.concatStringsSep ", " v6Dns} } counter masquerade'
    ''}
    ${pkgs.nftables}/bin/nft 'add rule inet ${bypassCfg.nftablesTable} postrouting ip daddr @bypass_v4 counter masquerade'
    ${pkgs.nftables}/bin/nft 'add rule inet ${bypassCfg.nftablesTable} postrouting ip6 daddr @bypass_v6 counter masquerade'
  '';
in
{
  options.networking.bypass = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = spec.bypassEnable or spec.amneziaBypassEnable or true;
      description = "Enable DNS-based domain bypassing of VPN tunnel for direct internet access to specified domains.";
    };

    domains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = spec.bypassDomains or spec.amneziaBypassDomains or [
        "nixos.org"
        "cachix.org"
        "flakehub.com"
        "garnix.io"
        "gitlab.com"
        "codeberg.org"
        "crates.io"
      ];
      description = "Domain suffixes to route directly via default gateway in bypass of VPN tunnel.";
    };

    dnsServers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = spec.bypassDnsServers or spec.amneziaDnsServers or [
        "1.1.1.1"
        "1.0.0.1"
      ];
      description = "Upstream DNS servers that always bypass the VPN tunnel directly via default gateway.";
    };

    mark = lib.mkOption {
      type = lib.types.int;
      default = 51820;
      description = "Firewall mark (fwmark) used for bypassing the tunnel routing table.";
    };

    nftablesTable = lib.mkOption {
      type = lib.types.str;
      default = "awg_bypass";
      description = "Name of the nftables table used for bypass marks and sets.";
    };
  };

  config = lib.mkMerge [
    {
      # NetworkManager Wi-Fi profiles
      networking.networkmanager.ensureProfiles = lib.mkIf hasWifi {
        profiles.${spec.wifiSSID} = {
          connection = {
            id = spec.wifiSSID;
            type = "wifi";
            autoconnect = "true";
          };
          wifi = {
            mode = "infrastructure";
            ssid = spec.wifiSSID;
          };
          wifi-security = {
            auth-alg = "open";
            key-mgmt = "wpa-psk";
            # psk is sourced from the machine-local hardware.nix (gitignored)
            psk = spec.wifiPass;
          };
          ipv4 = {
            method = "auto";
          };
          ipv6 = {
            addr-gen-mode = "stable-privacy";
            method = "auto";
          };
        };
      };

      # Firewall base configuration
      networking.firewall = {
        enable = lib.mkDefault true;
        # Loose reverse path prevents dropping bypass return packets arriving on physical interfaces
        checkReversePath = lib.mkDefault "loose";
      };

      # Essential kernel networking sysctls
      boot.kernel.sysctl = {
        "net.ipv4.conf.default.rp_filter" = lib.mkDefault 2;
        "net.ipv4.conf.all.rp_filter" = lib.mkDefault 2;
        "net.ipv4.ip_forward" = lib.mkDefault 1;
      };

      # Core networking tools for diagnostics and management
      environment.systemPackages = with pkgs; [
        iproute2
        nftables
        iptables
        dnsutils
        curl
        ethtool
        tcpdump
        traceroute
        conntrack-tools
      ];
    }

    (lib.mkIf (bypassCfg.enable && bypassCfg.domains != [ ]) {
      boot.kernelModules = [
        "nf_tables"
      ];

      networking.firewall.extraCommands = lib.mkAfter nftBypassCommands;

      networking.firewall.extraStopCommands = lib.mkAfter ''
        ${pkgs.nftables}/bin/nft 'delete table inet ${bypassCfg.nftablesTable}' 2>/dev/null || true
      '';

      services.dnsmasq = {
        enable = true;
        resolveLocalQueries = true;
        settings = {
          server = bypassCfg.dnsServers;
          nftset = map (domain: "/${domain}/4#inet#${bypassCfg.nftablesTable}#bypass_v4,6#inet#${bypassCfg.nftablesTable}#bypass_v6") bypassCfg.domains;
          # Ensure dnsmasq queries only the bypass upstream DNS servers and does not route queries into dead DHCP/tunnel resolvers
          no-resolv = true;
        };
      };

      systemd.services.dnsmasq = {
        after = [ "firewall.service" "network.target" ];
        wants = [ "firewall.service" ];
        preStart = lib.mkBefore nftBypassCommands;
        serviceConfig = {
          AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_NET_BIND_SERVICE" ];
        };
      };
    })
  ];
}
