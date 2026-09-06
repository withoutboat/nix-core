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

## Управление секретами с sops-nix и YubiKey

Для управления зашифрованными секретами используется [sops-nix](https://github.com/Mic92/sops-nix) с поддержкой [age-plugin-yubikey](https://github.com/str4d/age-plugin-yubikey). Приватный age-ключ хранится аппаратно на YubiKey.

### 1. Инициализация age-ключа на YubiKey

1. Вставьте YubiKey в USB-разъем.
2. Сгенерируйте age-ключ в слоте PIV YubiKey:
   ```bash
   age-plugin-yubikey
   ```
   Следуйте подсказкам мастера: выберите слот (по умолчанию 1), задайте PIN и настройте Touch Policy (запрос касания для расшифровки).

3. Получите публичный recipient ключа (начинается с `age1yubikey1...`):
   ```bash
   age-plugin-yubikey --list
   ```

4. Экспортируйте файл identity stub на хосте в `/var/lib/sops-nix/key.txt` (требуется `sops-nix` для расшифровки при сборке/активации системы):
   ```bash
   sudo mkdir -p /var/lib/sops-nix
   sudo sh -c 'age-plugin-yubikey --identity > /var/lib/sops-nix/key.txt'
   sudo chmod 600 /var/lib/sops-nix/key.txt
   ```
   *(Для работы с `sops` от обычного пользователя identity также можно сохранить в `~/.config/sops/age/keys.txt`)*

### 2. Настройка `.sops.yaml`

В корневом файле `.sops.yaml` укажите полученный recipient YubiKey:

```yaml
keys:
  - &yubikey age1yubikey1... # результат команды age-plugin-yubikey --list

creation_rules:
  - path_regex: secrets/.*\.ya?ml$
    key_groups:
      - age:
          - *yubikey
```

### 3. Создание и шифрование первого файла секретов

1. Создайте зашифрованный YAML-файл секретов (например, `secrets/secrets.yaml`):
   ```bash
   sops secrets/secrets.yaml
   ```
   В открывшемся редакторе добавьте секреты:
   ```yaml
   example_secret: my-secret-value
   ```
   После сохранения и выхода `sops` автоматически зашифрует данные указанным в `.sops.yaml` ключом.

2. Для шифрования существующего незашифрованного файла:
   ```bash
   sops --encrypt --in-place secrets/secrets.yaml
   ```

3. Для просмотра или редактирования зашифрованного файла:
   ```bash
   sops secrets/secrets.yaml
   ```
   (потребуется подключенный YubiKey; при запросе коснитесь кнопки и/или введите PIN).

### 4. Подключение секретов в NixOS

В модуле конфигурации подключите секрет через `sops`:

```nix
sops.defaultSopsFile = ../../secrets/secrets.yaml;
sops.secrets."example_secret" = {
  mode = "0400";
  owner = "root";
};
```
Расшифрованное значение будет смонтировано в `/run/secrets/example_secret`.
