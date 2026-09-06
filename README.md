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

## Secret Management with sops-nix and YubiKey

Encrypted secrets are managed using [sops-nix](https://github.com/Mic92/sops-nix) with [age-plugin-yubikey](https://github.com/str4d/age-plugin-yubikey). The private age key is stored in hardware on the YubiKey.

### 1. Initialize the age key on YubiKey (Automated)

1. Insert your YubiKey into a USB port.
2. Generate an age key non-interactively without PIN and touch requirements (so system rebuilds and services can decrypt secrets automatically during boot and activation without touching the YubiKey):
   ```bash
   age-plugin-yubikey --generate --slot 1 --pin-policy never --touch-policy never --name "pc-th"
   ```

3. Get the public recipient for `.sops.yaml` (starts with `age1yubikey1...`):
   ```bash
   age-plugin-yubikey --list
   ```

4. Export the identity stub file directly into the repository:
   ```bash
   age-plugin-yubikey --identity > secrets/yubikey-identity.txt
   ```
   *Note: `secrets/yubikey-identity.txt` contains only the hardware reference (identity stub), not the private key (which never leaves the YubiKey). When committed, `modules/sops.nix` automatically uses this file on clean disk installs without requiring manual `/var/lib/sops-nix/key.txt` setup.*

### 2. Configure `.sops.yaml`

In the root `.sops.yaml` file, specify your YubiKey recipient:

```yaml
keys:
  - &yubikey age1yubikey1... # Output from age-plugin-yubikey --list

creation_rules:
  - path_regex: secrets/.*\.ya?ml$
    key_groups:
      - age:
          - *yubikey
```

### 3. Create and encrypt your first secret file

1. Create an encrypted YAML secrets file (e.g., `secrets/secrets.yaml`):
   ```bash
   sops secrets/secrets.yaml
   ```
   Add your secrets in the editor:
   ```yaml
   example_secret: my-secret-value
   ```
   Upon saving and exiting, `sops` automatically encrypts the data using the key defined in `.sops.yaml`.

2. To encrypt an existing unencrypted file in-place:
   ```bash
   sops --encrypt --in-place secrets/secrets.yaml
   ```

3. To view or edit an encrypted file:
   ```bash
   sops secrets/secrets.yaml
   ```
   (YubiKey must be plugged in; touch the key and/or enter PIN when prompted).

### 4. Use secrets in NixOS

In your configuration module, declare secrets via `sops`:

```nix
sops.defaultSopsFile = ../../secrets/secrets.yaml;
sops.secrets."example_secret" = {
  mode = "0400";
  owner = "root";
};
```
The decrypted secret will be mounted at `/run/secrets/example_secret`.
