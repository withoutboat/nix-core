{ config, pkgs, lib, ... }:

let
  contextPath = ../runtime-context.nix;
  context = if builtins.pathExists contextPath
            then import contextPath
            else { cpu = "amd"; gpu = "none"; };
in
{
  hardware.cpu.amd.updateMicrocode = lib.mkIf (context.cpu == "amd") true;
  hardware.cpu.intel.updateMicrocode = lib.mkIf (context.cpu == "intel") true;

  hardware.graphics = lib.mkIf (context.gpu != "none") {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = lib.mkIf (lib.hasSuffix "nvidia" context.gpu) [ "nvidia" ];
  hardware.nvidia = lib.mkIf (lib.hasSuffix "nvidia" context.gpu) {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = context.nvidiaOpen or false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  systemd.tmpfiles.rules = lib.mkIf (lib.hasPrefix "amd" context.gpu) [
    "L+ /extra/acls - - - - /sys/class/drm/card0/device/power_dpm_force_performance_level"
  ];

  hardware.nvidia.prime = lib.mkIf (context.gpu == "hybrid-amd-nvidia" || context.gpu == "intel-nvidia") {
    offload = {
      enable = true;
      enableOffloadCmd = true;
    };
  };
}
