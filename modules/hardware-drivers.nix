{ config, pkgs, lib, spec ? { cpu = "amd"; gpu = "none"; nvidiaOpen = false; }, ... }:

{
  hardware.cpu.amd.updateMicrocode = lib.mkIf (spec.cpu == "amd") true;
  hardware.cpu.intel.updateMicrocode = lib.mkIf (spec.cpu == "intel") true;

  hardware.graphics = lib.mkIf (spec.gpu != "none") {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = lib.mkIf (lib.hasSuffix "nvidia" spec.gpu) [ "nvidia" ];
  
  hardware.nvidia = lib.mkIf (lib.hasSuffix "nvidia" spec.gpu) {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = spec.nvidiaOpen;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  systemd.tmpfiles.rules = lib.mkIf (lib.hasPrefix "amd" spec.gpu) [
    "L+ /extra/acls - - - - /sys/class/drm/card0/device/power_dpm_force_performance_level"
  ];

  hardware.nvidia.prime = lib.mkIf (spec.gpu == "hybrid-amd-nvidia" || spec.gpu == "intel-nvidia") {
    offload = {
      enable = true;
      enableOffloadCmd = true;
    };
  };
}
