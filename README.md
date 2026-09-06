# nix-core

## Host directories

Host entrypoints now live under `hosts/<name>/default.nix` so they are compatible with `nixos-bootstrapper`.

- `hosts/pc-th/default.nix` is the machine entrypoint for `.#pc-th`
- `hosts/iso-installer/default.nix` is the ISO host/profile used by `.#iso-installer`
- bootstrapper-generated machine-local files stay next to the host entrypoint as `hosts/<name>/hardware.nix` and `hosts/<name>/configuration.nix`

`hosts/<name>/configuration.nix` can provide runtime values through `_module.args.spec` (for example `username`, `cpu`, `gpu`, `nvidiaOpen`, Wi-Fi settings, and PRIME bus IDs). These generated files are gitignored and should not be moved back to the repository root.

For `pc-th`, `hosts/pc-th/hardware.nix` is required once `hosts/pc-th/configuration.nix` has been generated. This keeps clean GitHub evaluation working while still making `nixos-install --flake .#pc-th` fail clearly until the bootstrapper has written the machine-specific hardware file.

### Rebuild commands

Build the installer ISO:

```bash
nix build .#iso-installer
```

Rebuild the `pc-th` host after the bootstrapper has generated `hosts/pc-th/hardware.nix` and `hosts/pc-th/configuration.nix`:

```bash
sudo nixos-rebuild switch --flake .#pc-th
```


## `pc-th` AmneziaWG integration

`pc-th` imports the local `modules/amneziawg.nix` module and enables the system
tunnel as `awg0`.

- Machine-specific test config path in this repo: `secrets/amnezia_for_awg.conf`
- The file is passed to `services.amneziawg.configFile` from `hosts/pc-th/default.nix`.
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

3. Verify the service and connection:

   ```bash
   systemctl status awg-quick-awg0
   sudo awg show
   ```

If you rename the interface, the systemd unit name changes to
`awg-quick-<interfaceName>` (with `wg-quick-<interfaceName>` retained as an alias).

⚠️ `secrets/amnezia_for_awg.conf` currently contains intentionally published
test keys for validation. Treat these keys as compromised and replace the config
and all related keys after verification.
