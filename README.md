# nix-core

## Host directories

Host entrypoints now live under `hosts/<name>/default.nix` so they are compatible with `nixos-bootstrapper`.

- `hosts/pc-th/default.nix` is the machine entrypoint for `.#pc-th`
- `hosts/iso-installer/default.nix` is the ISO host/profile used by `.#iso-installer`
- bootstrapper-generated machine-local files stay next to the host entrypoint as `hosts/<name>/hardware.nix` and `hosts/<name>/configuration.nix`

`hosts/<name>/configuration.nix` can provide runtime values through `_module.args.spec` (for example `username`, `cpu`, `gpu`, `nvidiaOpen`, Wi-Fi settings, PRIME bus IDs, and `amneziaConfig`). These generated files are gitignored and should not be moved back to the repository root.

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

`pc-th` imports the local `modules/amneziawg.nix` module.

- Config filename is specified in `hosts/<name>/configuration.nix` via `_module.args.spec.amneziaConfig` (e.g. `"amnezia_for_awg.conf"`).
- When `amneziaConfig` is set and the encrypted file exists in `secrets/`, `modules/amneziawg.nix` automatically registers the SOPS binary secret and enables the system tunnel as `awg0`.
- With `networking.networkmanager.enable = true`, the module orders the
  `wg-quick-awg0` unit after `NetworkManager-wait-online.service` and `sops-nix.service`.

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
   *Note: `secrets/yubikey-identity.txt` contains only the hardware reference (identity stub), not the private key (which never leaves the YubiKey). When committed, `modules/sops.nix` declaratively symlinks this file to `/etc/sops/age/keys.txt` without requiring manual key setup.*

### 2. Configure `.sops.yaml`

In the root `.sops.yaml` file, specify your YubiKey recipient and creation rules:

```yaml
keys:
  - &yubikey age1yubikey1... # Output from age-plugin-yubikey --list

creation_rules:
  # 1. Structured YAML secrets (encrypts only values, keeps keys cleartext)
  - path_regex: secrets/.*\.ya?ml$
    key_groups:
      - age:
          - *yubikey

  # 2. Whole raw/binary files (encrypts the entire file content)
  - path_regex: secrets/.*(\.conf|\.bin|\.raw|\.key|\.env)$
    input_type: binary
    output_type: binary
    key_groups:
      - age:
          - *yubikey
```

#### `.sops.yaml` key options explained:
- **`path_regex`**: RegEx pattern determining which files apply to this rule.
- **`input_type` / `output_type`**:
  - `yaml` / `json` (default for matching extensions): Encrypts values while preserving tree structure and key names.
  - `binary`: Encrypts the entire file as a single raw blob (ideal for whole configs like WireGuard/Amnezia, certificates, or SSH keys).
  - `dotenv`: Key-value `.env` files.
- **`encrypted_regex`**: (Optional) Regex to selectively encrypt only specific keys in structured files (e.g. `^(token|password|.*_key)$`), keeping non-sensitive metadata readable in Git diffs.
- **`key_groups`**: List of recipient key groups (can contain multiple age or PGP keys, e.g. for backup keys).

---

### 3. Encrypting Secrets

#### A. Structured Key-Value Secrets (YAML)
1. Create or edit an encrypted YAML file:
   ```bash
   sops secrets/secrets.yaml
   ```
   Add your secrets:
   ```yaml
   user_password: my-secure-password
   api_token: eyJhbGciOi...
   ```
   Upon save & exit, SOPS automatically encrypts the values.

2. Encrypt an existing unencrypted file in-place:
   ```bash
   sops --encrypt --in-place secrets/secrets.yaml
   ```

#### B. Whole Files (Config Files, Certificates, Private Keys)
To encrypt an entire configuration file (like `secrets/amnezia_for_awg.conf`) as a whole without altering its format:

1. Encrypt in-place using SOPS binary mode:
   ```bash
   sops --encrypt --in-place secrets/amnezia_for_awg.conf
   ```
   *(Or without `--in-place` to a separate file: `sops -e secrets/raw.conf > secrets/raw.enc.conf`)*

2. View or edit the encrypted whole file in your editor:
   ```bash
   sops secrets/amnezia_for_awg.conf
   ```

3. Alternatively, embed whole file contents inside a YAML secret:
   ```yaml
   amnezia_conf: |
     [Interface]
     PrivateKey = ...
     Address = ...
   ```

---

### 4. Use Secrets in NixOS

In your NixOS module (e.g. `hosts/pc-th/default.nix`):

```nix
{ config, ... }:
{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;

    secrets = {
      # 1. From default YAML file
      "user_password" = {
        neededForUsers = true; # for user passwords during boot
      };

      # 2. Entire whole/binary file
      "amnezia_for_awg.conf" = {
        format = "binary";
        sopsFile = ../../secrets/amnezia_for_awg.conf;
        mode = "0400";
        owner = "root";
      };
    };
  };

  # Pass the decrypted path to services:
  services.amneziawg = {
    enable = true;
    configFile = config.sops.secrets."amnezia_for_awg.conf".path;
  };
}
```
All decrypted secret files are securely mounted in RAM at `/run/secrets/<name>` (e.g. `/run/secrets/amnezia_for_awg.conf`).

---

## YubiKey Authentication for sudo and Login (PAM U2F)

To use your YubiKey instead of entering a password for login (`greetd`/`tuigreet`), `sudo` commands, and `polkit` elevation dialogs:

### 1. Register YubiKey (One-time)
Insert your YubiKey into a USB port and run `pamu2fcfg` to generate the U2F mapping (touch the key when prompted):
```bash
pamu2fcfg -u withoutboat | sudo tee /etc/u2f_mappings
```

To persist the registration in the repository (so clean disk installs automatically provision it via a declarative `/etc/u2f_mappings` symlink):
```bash
cp /etc/u2f_mappings secrets/u2f_mappings
```

### 2. How it works
* When running `sudo` or on the login screen, a `Please touch the device.` prompt appears and the YubiKey LED blinks.
* Touch the sensor on the YubiKey to authenticate immediately without typing a password.
* If the key is not inserted, PAM gracefully falls back to the standard password prompt thanks to `control = "sufficient"` and `nouserok = true`.

