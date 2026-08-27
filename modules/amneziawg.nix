{ config, lib, ... }:
let
  cfg = config.services.amneziawg;
in
{
  options.services.amneziawg = {
    enable = lib.mkEnableOption "AmneziaWG interface via wg-quick";

    interfaceName = lib.mkOption {
      type = lib.types.str;
      default = "awg0";
      description = "AmneziaWG interface name.";
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/amnezia/amnezia.conf";
      description = "Path to AmneziaWG config file used by wg-quick at runtime.";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to autostart the AmneziaWG interface.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.configFile != null && cfg.configFile != "";
        message = "services.amneziawg.configFile must be set when services.amneziawg.enable = true.";
      }
    ];

    networking.wg-quick.interfaces.${cfg.interfaceName} = {
      type = "amneziawg";
      configFile = cfg.configFile;
      autostart = cfg.autoStart;
    };
  };
}
