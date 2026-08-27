{ config, inputs, lib, ... }:
let
  cfg = config.services.amneziawg;
  serviceName = "wg-quick-${cfg.interfaceName}";
in
{
  imports = [
    inputs.nix-home.nixosModules.amnezia
  ];

  services.amneziawg = {
    enable = true;
    interfaceName = "awg0";
    configFile = "/run/secrets/amnezia/amnezia.conf";
    autoStart = true;
    killSwitch.enable = false;
  };

  systemd.services.${serviceName} = lib.mkIf cfg.enable {
    unitConfig.ConditionPathExists = cfg.configFile;
  };
}
