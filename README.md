# nix-core

## `pc-th` AmneziaWG integration

`pc-th` imports the local `modules/amneziawg.nix` module and enables the system
tunnel as `awg0`.

- Machine-specific test config path in this repo: `secrets/amnezia_for_awg.conf`
- The file is passed to `services.amneziawg.configFile` from `hosts/pc-th.nix`.
- With `networking.networkmanager.enable = true`, the module orders the
  `wg-quick-awg0` unit after `NetworkManager-wait-online.service`.

For a full tunnel, keep the routing in the config file, including
`AllowedIPs = 0.0.0.0/0` and `AllowedIPs = ::/0` when needed, plus any endpoint
reachability rules required by your provider's `amneziawg` config.

This module does not configure a generic kill-switch automatically.

### After merge

1. If you prefer a generated lockfile, refresh the input pin locally:

   ```bash
   nix flake lock --update-input nix-home
   ```

2. Rebuild `pc-th`:

   ```bash
   sudo nixos-rebuild switch --flake .#pc-th
   ```

3. Verify the service without dumping the config:

   ```bash
   systemctl status wg-quick-awg0
   ```

If you rename the interface, the systemd unit name changes to
`wg-quick-<interfaceName>`.

⚠️ `secrets/amnezia_for_awg.conf` currently contains intentionally published
test keys for validation. Treat these keys as compromised and replace the config
and all related keys after verification.
