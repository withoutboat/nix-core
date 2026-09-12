{ pkgs, lib, ... }:

{
  # Enable compressed swap in RAM to prevent system freezes and OOM during heavy builds
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # Protect interactive desktop & terminal from nix build starvation
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 2d";
    };
  };

  # Prevent total kernel freezes under extreme memory pressure
  services.earlyoom = {
    enable = true;
    enableNotifications = true;
  };
}
