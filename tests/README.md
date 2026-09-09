# Сетевая диагностика и тесты (Network Diagnostics & Tests)

Данный каталог содержит комплекс инструментов, скриптов автоматизации и документацию для **полного и исключительного понимания** того, что происходит с сетью, файрволом, DNS и VPN-туннелями на машине под управлением NixOS (`pc-th`).

---

## Быстрый старт (Quick Start)

Все скрипты расположены в директории `tests/` и готовы к запуску.

### 1. Полный сбор диагностических данных

Запуск полной автоматизированной диагностики сетевого стека:

```bash
sudo ./tests/diagnose-network.sh
```

- Автоматически собирает полный срез состояния системы (интерфейсы, маршрутизация, DNS, nftables, iptables, сервисы, туннель, пинги и curl-запросы).
- Создаёт отдельную директорию `tests/<YYYY-MM-DD_HH-MM-SS>/` (или `tests/<date>`) со всеми сырыми логами.
- Генерирует сводный отчёт `tests/<date>/report.md` с таблицей статусов.
- Обновляет удобный симлинк `tests/latest` на последний прогон.

Можно явно передать путь или дату для сохранения результатов:

```bash
sudo ./tests/diagnose-network.sh tests/$(date +%Y-%m-%d)
```

### 2. Быстрая проверка связности и байпасов

Быстрый чек всех ключевых компонентов с понятным выводом `PASS` / `WARN` / `FAIL`:

```bash
sudo ./tests/check-connectivity.sh
```

Проверяет:
1. Доступность физического шлюза (LAN Gateway).
2. Прямой пинг upstream DNS (1.1.1.1).
3. Работу локального резолвера dnsmasq на `127.0.0.1:53`.
4. Корректность `/etc/resolv.conf`.
5. Существование таблицы `inet awg_bypass` и сетов `bypass_v4` / `bypass_v6`.
6. Динамическое наполнение nftset при резолве доменов (например, `github.com`).
7. HTTPS-доступность доменов байпаса (`github.com`, `nixos.org`).
8. Статус туннеля AmneziaWG (`awg0`) и наличие handshake.
9. Выход в глобальный интернет через полный туннель.

### 3. Тестирование механизма доменного байпаса

Глубокая проверка связки `dnsmasq` -> `nftset` -> `fwmark 51820` -> `table main`:

```bash
sudo ./tests/test-dnsmasq-bypass.sh github.com
```

---

## Структура вывода `tests/<date>/`

Каждый запуск `diagnose-network.sh` формирует в `tests/<date>/` структурированный набор файлов:

```text
tests/<date>/
├── report.md                  # Сводный Markdown-отчёт с таблицей проверок
├── 01-system-info.log         # Ядро, хостнейм, аптайм, загруженные модули
├── 02-interfaces.log          # ip link, ip addr, статистика пакетов, nmcli
├── 03-routing.log             # ip rule, table main, table 51820, route get
├── 04-dns.log                 # resolv.conf, dnsmasq configs, dig, getent
├── 05-firewall-nftables.log   # nft list ruleset, awg_bypass set, iptables -S
├── 06-sysctl.log              # rp_filter, ip_forward, forwarding
├── 07-services.log            # systemctl status и journalctl для всех служб
└── 08-connectivity.log        # awg show, ping, curl тесты доменов и внешнего IP
```

---

## Исчерпывающий справочник команд (Manual Inspection Commands)

Если требуется вручную понять, что происходит с сетью на машине:

### 1. Интерфейсы и физический уровень
```bash
# Список всех интерфейсов, флаги состояния (UP/DOWN), MTU и MAC-адреса
ip -details link show

# Все назначенные IPv4 и IPv6 адреса
ip -brief addr show
ip -4 addr show
ip -6 addr show

# Ошибки, сброшенные пакеты (drops), коллизии на интерфейсах
ip -s link

# Состояние устройств и подключений в NetworkManager
nmcli device status
nmcli connection show --active
```

### 2. Маршрутизация и Policy Routing (FIB)
```bash
# Правила маршрутизации (Policy Routing Rules / FIB):
# Показывает, в каком порядке и по каким условиям (fwmark, suppress) опрашиваются таблицы
ip -4 rule show
ip -6 rule show

# Основная таблица маршрутизации (физический шлюз, локальная подсеть Wi-Fi/Ethernet)
ip -4 route show table main

# Таблица маршрутизации VPN (awg-quick направляет 0.0.0.0/0 в awg0)
ip -4 route show table 51820

# Проверка, через какой интерфейс и с каким source IP ядро отправит пакет:
# Без метки (пойдёт в awg0):
ip route get 1.1.1.1
ip route get 140.82.121.4

# С меткой байпаса 51820 (пойдёт через физический шлюз wlp1s0 / enp...):
ip route get 1.1.1.1 mark 51820
ip route get 140.82.121.4 mark 51820
```

### 3. DNS и разрешение имён
```bash
# Текущий системный файл резолвера (должен содержать nameserver 127.0.0.1)
cat /etc/resolv.conf

# Проверка прямого ответа от локального dnsmasq
dig @127.0.0.1 github.com +short

# Проверка ответа от upstream DNS напрямую через байпас
dig @1.1.1.1 github.com +short

# Проверка через glibc getent (так, как резолвят curl, git, браузеры)
getent hosts github.com
getent hosts nixos.org
```

### 4. Файрвол и nftables
```bash
# Полный дамп всех правил nftables
sudo nft list ruleset

# Просмотр таблицы байпаса
sudo nft list table inet awg_bypass

# Просмотр IP-адресов, динамически добавленных dnsmasq в сет байпаса
sudo nft list set inet awg_bypass bypass_v4
sudo nft list set inet awg_bypass bypass_v6

# Просмотр классических правил iptables (если включен firewall-iptables)
sudo iptables -S
sudo iptables -t nat -S
sudo iptables -t mangle -S
```

### 5. AmneziaWG / WireGuard
```bash
# Текущий статус туннеля (публичные ключи, endpoint, handshake, трафик rx/tx)
sudo awg show
sudo wg show

# Статус системной службы туннеля
systemctl status awg-quick-awg0.service --no-pager
journalctl -u awg-quick-awg0.service -n 50 --no-pager
```

### 6. Системные службы
```bash
# Статус NetworkManager, dnsmasq, firewall
systemctl status NetworkManager.service --no-pager
systemctl status dnsmasq.service --no-pager
systemctl status firewall.service --no-pager

# Логи dnsmasq (проверка, нет ли ошибок прав доступа к nftset)
journalctl -u dnsmasq.service -n 50 --no-pager
```

### 7. Параметры ядра (sysctl)
```bash
# Настройки фильтрации обратного пути (rp_filter)
# 0 = выключен, 1 = строгий (strict), 2 = мягкий (loose)
sysctl -a | grep -E '\.rp_filter'

# Маршрутизация пакетов (ip_forward)
sysctl net.ipv4.ip_forward
```

---

## Архитектура работы сети и байпаса

### 1. Почему не работал интернет при всех включенных сервисах?
1. **Тестовые ключи в конфиге AmneziaWG**: В `secrets/amnezia_for_awg.conf` находятся тестовые ключи. При автозапуске службы `awg-quick-awg0` утилита `awg-quick` перехватывает весь трафик (`AllowedIPs = 0.0.0.0/0`) через правило `not fwmark 51820 lookup 51820`. Если сервер не отвечает, весь трафик уходит в чёрную дыру.
2. **Засорение DNS-серверов в dnsmasq**: Если NetworkManager передаёт через DHCP адреса DNS (например, провайдерские или внешние 8.8.8.8), а `no-resolv` не установлен, `dnsmasq` пытается опрашивать эти адреса. Они не помечены меткой байпаса, уходят в мёртвый туннель `awg0` и вызывают таймаут разрешения имён. С параметром `no-resolv = true` запросы идут **только** на адреса из `networking.bypass.dnsServers` (1.1.1.1, 1.0.0.1), которые гарантированно имеют метку `51820` и всегда идут мимо туннеля.
3. **Drop обратных пакетов (rp_filter)**: Когда ядро отправляет байпас-пакет через `wlp1s0` с меткой `51820`, ответный пакет приходит на физический интерфейс. Если в файрволе включен строгий `checkReversePath`, файрвол отбрасывает ответ. Установка `checkReversePath = "loose"` решает эту проблему.
4. **Права dnsmasq на запись в nftables**: `dnsmasq` при старте сбрасывает привилегии до непривилегированного пользователя. Для добавления записей в `nftset` сервису необходима capability `CAP_NET_ADMIN`.

### 2. Как устроен раздельный туннель (Split Tunnel)
```text
 Приложение (curl https://github.com)
     │
     ▼
 1. Резолв DNS -> 127.0.0.1:53 (dnsmasq)
     │
     ├─► dnsmasq отправляет запрос на 1.1.1.1
     │   (в nftables адрес 1.1.1.1 имеет правило: meta mark set 51820 -> идёт через физический шлюз)
     │
     ├─► Получен ответ (например, 140.82.121.4)
     │   dnsmasq автоматически выполняет:
     │   add element inet awg_bypass bypass_v4 { 140.82.121.4 }
     │
     ▼
 2. Подключение к 140.82.121.4:443
     │
     ├─► nftables output chain (mangle):
     │   ip daddr @bypass_v4 -> meta mark set 51820
     │
     ├─► Policy Routing:
     │   not fwmark 51820 lookup 51820  (НЕ СРАБАТЫВАЕТ, так как метка есть!)
     │   lookup main                     (СРАБАТЫВАЕТ -> идёт через default gateway Wi-Fi)
     │
     └─► nftables postrouting chain:
         meta mark 51820 masquerade -> SNAT в адрес Wi-Fi интерфейса
```
Любые домены, не входящие в список байпаса, не попадают в `@bypass_v4`, не получают метку `51820` и безопасно идут внутри защищённого туннеля `awg0`.
