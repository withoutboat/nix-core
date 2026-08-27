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
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    boot.extraModulePackages = [
      config.boot.kernelPackages.amneziawg
    ];

    boot.kernelModules = [
      "amneziawg"
    ];

    assertions = [
      {
        assertion = cfg.configFile != null;
        message =
          "services.amneziawg.configFile must be set when AmneziaWG is enabled.";
      }
    ];

    networking.wg-quick.interfaces.${cfg.interfaceName} = {
      type = "amneziawg";
      configFile = cfg.configFile;
      autostart = cfg.autoStart;
    };
  };
}
