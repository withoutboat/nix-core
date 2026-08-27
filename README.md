# nix-core

## `pc-th` AmneziaWG integration

`pc-th` imports `inputs.nix-home.nixosModules.amnezia` through
`modules/amneziawg.nix` and enables the system tunnel as `awg0`.

- Secret config path: `/run/secrets/amnezia/amnezia.conf`
- Recommended owner/group: `root:root`
- Recommended mode: `0600`
- The tunnel unit is skipped until that file exists.
- With `networking.networkmanager.enable = true`, the upstream module orders the
  `wg-quick-awg0` unit after `NetworkManager-wait-online.service`.

The external `amnezia.conf` must stay out of Git and out of `/nix/store`. For a
full tunnel, keep the routing in the external file, including
`AllowedIPs = 0.0.0.0/0` and `AllowedIPs = ::/0` when needed, plus any endpoint
reachability rules required by your provider's `amneziawg` config.

The upstream module intentionally leaves `services.amneziawg.killSwitch.enable`
disabled; no generic kill-switch is configured here.

### After merge

1. Place your local config at `/run/secrets/amnezia/amnezia.conf`.
2. Set permissions without printing secrets:

   ```bash
   sudo install -d -m 700 /run/secrets/amnezia
   sudo install -m 600 -o root -g root ./amnezia.conf /run/secrets/amnezia/amnezia.conf
   ```

3. If you prefer a generated lockfile, refresh the input pin locally:

   ```bash
   nix flake lock --update-input nix-home
   ```

4. Rebuild `pc-th`:

   ```bash
   sudo nixos-rebuild switch --flake .#pc-th
   ```

5. Verify the service without dumping the config:

   ```bash
   systemctl status wg-quick-awg0
   ```

If you rename the interface, the systemd unit name changes to
`wg-quick-<interfaceName>`.
