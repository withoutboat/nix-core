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

## [Сетевая диагностика и тесты (Network Diagnostics & Tests)](tests/README.md)

Полный набор автоматизированных тестов и скриптов сбора диагностики расположен в папке [`tests/`](tests/README.md).

- **Полная автоматическая диагностика**:
  ```bash
  sudo ./tests/diagnose-network.sh
  ```
  Собирает исчерпывающий срез состояния сетевого стека (интерфейсы, маршрутизацию, DNS, nftables, iptables, логи служб, пинги) в папку `tests/<date>/` и генерирует `tests/<date>/report.md`.
- **Быстрая проверка связности и байпасов**:
  ```bash
  sudo ./tests/check-connectivity.sh
  ```
- **Тестирование связки dnsmasq + nftset + policy routing**:
  ```bash
  sudo ./tests/test-dnsmasq-bypass.sh nixos.org
  ```

Подробное руководство по командам ручной инспекции и архитектуре раздельного туннеля см. в **[tests/README.md](tests/README.md)**.


## Сетевая архитектура и интеграция AmneziaWG (`pc-th`)

Сетевая система модульная и разделена на два специализированных модуля:

### 1. `modules/networks.nix` (Сети, файрвол, DNS и байпас)
- **Wi-Fi**: Декларативное создание профилей NetworkManager через `networking.networkmanager.ensureProfiles` на основе `spec.wifiSSID` и `spec.wifiPass`.
- **Файрвол и фильтрация**: Настройка `networking.firewall` с `checkReversePath = "loose"` для корректного приёма ответных пакетов по маршрутам раздельного туннелирования.
- **Раздельный туннель (Domain Bypass)**:
  - Опция `networking.bypass.enable` (по умолчанию `true`).
  - Трафик к кэшам Nix и репозиториям (`nixos.org`, `cachix.org`, `flakehub.com`, `garnix.io`, `gitlab.com`, `codeberg.org`, `crates.io`) автоматически пускается напрямую через шлюз по умолчанию (трафик GitHub направляется через VPN для работы Copilot и других сервисов).
  - Управляется через `dnsmasq` и `nftables`: `dnsmasq` динамически наполняет сет `@bypass_v4` в таблице `inet awg_bypass`, а цепочка `output` помечает пакеты меткой `51820`, направляя их в `table main`.
  - Защита DNS: `dnsmasq` настроен с `no-resolv = true`, исключая задержки и зависания из-за недоступных DNS-серверов внутри туннеля или некорректных DHCP-ответов.
- **Параметры ядра**: `rp_filter = 2` (loose) и включение `ip_forward`.

### 2. `modules/amneziawg.nix` (Изолированная логика AmneziaWG)
- Отвечает исключительно за туннельный интерфейс AmneziaWG:
  - Загрузка модулей ядра (`amneziawg`) и системных пакетов (`amneziawg-tools`, `amneziawg-go`).
  - Автоматическая регистрация SOPS-бинарного секрета по `_module.args.spec.amneziaConfig` (например, `"amnezia_for_awg.conf"`).
  - Управление жизненным циклом службы `awg-quick-${cfg.interfaceName}`.
  - Удаление строк `DNS =` из конфига перед запуском `awg-quick`, предотвращая затирание `/etc/resolv.conf`.
  - Маркировка интерфейса как неконтролируемого NetworkManager (`unmanaged`).

Для полного туннеля сохраняйте маршруты в конфигурационном файле, включая `AllowedIPs = 0.0.0.0/0` и `AllowedIPs = ::/0`.

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
Insert your YubiKey into a USB port and run `pamu2fcfg` to generate the U2F mapping (touch the key when prompted, specifying your hostname as origin and appid):
```bash
pamu2fcfg -o pam://pc-th -i pam://pc-th -u withoutboat | sudo tee /etc/u2f_mappings
```

To persist the registration in the repository (so clean disk installs automatically provision it via a declarative `/etc/u2f_mappings` symlink):
```bash
cp /etc/u2f_mappings secrets/u2f_mappings
```

### 2. How it works
* When running `sudo` or on the login screen, a `Please touch the device.` prompt appears and the YubiKey LED blinks.
* Touch the sensor on the YubiKey to authenticate immediately without typing a password.
* If the key is not inserted, PAM gracefully falls back to the standard password prompt thanks to `control = "sufficient"` and `nouserok = true`.

