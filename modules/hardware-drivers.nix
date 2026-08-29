{ config, pkgs, lib, spec ? {}, ... }:

let
  cpu = spec.cpu or "amd";
  gpu = spec.gpu or "none";
  nvidiaOpen = spec.nvidiaOpen or false;
  hasIntelNvidiaPrime = gpu == "intel-nvidia"
    && (spec ? intelBusId) && spec.intelBusId != ""
    && (spec ? nvidiaBusId) && spec.nvidiaBusId != "";
in
{
  hardware.enableRedistributableFirmware = true;

  hardware.cpu.amd.updateMicrocode = lib.mkIf (cpu == "amd") true;
  hardware.cpu.intel.updateMicrocode = lib.mkIf (cpu == "intel") true;

  hardware.graphics = lib.mkIf (gpu != "none") {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
    ];
  };

  services.xserver.videoDrivers = 
    lib.optional (lib.hasSuffix "nvidia" gpu) "nvidia" ++ [ "modesetting" ];

  hardware.nvidia = lib.mkIf (lib.hasSuffix "nvidia" gpu) (lib.mkMerge [
    {
      modesetting.enable = true;
      powerManagement.enable = false;
      open = nvidiaOpen;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
    }
    (lib.mkIf hasIntelNvidiaPrime {
      prime = {
        intelBusId = spec.intelBusId;
        nvidiaBusId = spec.nvidiaBusId;
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
      };
    })
  ]);

  assertions = lib.optional (gpu == "intel-nvidia") {
    assertion = hasIntelNvidiaPrime;
    message = "spec.intelBusId and spec.nvidiaBusId must be set for intel-nvidia PRIME systems.";
  };

  systemd.tmpfiles.rules = lib.mkIf (lib.hasPrefix "amd" gpu) [
    "L+ /extra/acls - - - - /sys/class/drm/card0/device/power_dpm_force_performance_level"
  ];
}
