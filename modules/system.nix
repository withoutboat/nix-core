{ pkgs, lib, ... }:

let
  systemCleanup = pkgs.writeShellScriptBin "system-cleanup" ''
    set -euo pipefail
    echo "=== Cleaning up Nix garbage and old generations ==="
    nix-collect-garbage --delete-older-than 3d || true

    echo "=== Pruning git worktrees ==="
    find "$HOME" -maxdepth 4 -type d -name ".git" 2>/dev/null | while read -r gitdir; do
      repo=$(dirname "$gitdir")
      (cd "$repo" && git worktree prune 2>/dev/null || true)
    done

    echo "=== Memory and swap status ==="
    free -h
    if command -v zramctl >/dev/null 2>&1; then
      echo "=== zram status ==="
      zramctl
    fi
  '';
in
{
  # Compressed swap in RAM with zstd compression to multiply effective memory
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 100;
  };

  # Secondary disk swapfile as safety net for extreme memory spikes (priority 10 so zram is used first)
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8192; # 8 GB safety net
      priority = 10;
    }
  ];

  # Kernel sysctl parameters for responsive desktop under high memory pressure
  boot.kernel.sysctl = {
    # Prioritize compressing anonymous memory to zram instead of dropping disk cache (prevents desktop freeze)
    "vm.swappiness" = 180;
    # Disable watermark boost to avoid sudden reclaim stalls
    "vm.watermark_boost_factor" = 0;
    # Start page reclaim earlier to avoid abrupt OOM cliffs
    "vm.watermark_scale_factor" = 125;
    # Single page read/write for zram instead of multi-page clusters
    "vm.page-cluster" = 0;
    # Smooth dirty page writeouts
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
  };

  # Protect interactive desktop & terminal from nix build starvation
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      max-jobs = "auto";
      cores = 0;
    };
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 3d";
    };
  };

  # Prevent nix builds from swallowing all host memory and freezing the desktop
  systemd.services.nix-daemon.serviceConfig = {
    MemoryAccounting = true;
    MemoryHigh = "75%";
    MemoryMax = "85%";
  };

  # Enable memory accounting for user sessions and cgroups
  systemd.user.settings.Manager = {
    DefaultMemoryAccounting = true;
    DefaultCPUAccounting = true;
  };

  # Targeted earlyoom: protect desktop & sessions, target memory hogs before freeze
  services.earlyoom = {
    enable = true;
    enableNotifications = true;
    freeMemThreshold = 4;
    freeSwapThreshold = 10;
    extraArgs = [
      "-g"
      "--avoid" "^(Hyprland|waybar|greetd|systemd|dbus-daemon|pipewire|wireplumber|Xwayland)$"
      "--prefer" "^(copilot.*|electron.*|node|cargo|rustc|cc1plus|c\\+\\+|nix-daemon)$"
    ];
  };

  environment.systemPackages = [
    systemCleanup
    pkgs.btop
  ];
}
