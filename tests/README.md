# Network Diagnostics & Tests

This directory contains a comprehensive suite of tools, automation scripts, and documentation for a **complete and definitive understanding** of what is happening with the network, firewall, DNS, and VPN tunnels on a NixOS machine (`pc-th`).

---

## Quick Start

All scripts are located in the `tests/` directory and are ready to run.

### 1. Comprehensive Diagnostic Data Collection

Run full automated diagnostics of the entire network stack:

```bash
sudo ./tests/diagnose-network.sh
```

- Automatically collects a full snapshot of the system state (interfaces, routing rules, DNS, nftables, iptables, services, tunnel, ping, and curl probes).
- Creates an isolated directory `tests/<YYYY-MM-DD_HH-MM-SS>/` (or `tests/<date>`) containing all raw logs.
- Generates a summary report `tests/<date>/report.md` with a status overview table.
- Updates the convenient `tests/latest` symlink pointing to the most recent run.

You can also explicitly specify a target directory or date for saving the results:

```bash
sudo ./tests/diagnose-network.sh tests/$(date +%Y-%m-%d)
```

### 2. Rapid Connectivity & Bypass Health Check

Quick assertion check across all key components with clear `PASS` / `WARN` / `FAIL` status:

```bash
sudo ./tests/check-connectivity.sh
```

Verifies:
1. Physical LAN Gateway reachability.
2. Direct ping to upstream DNS (`1.1.1.1`).
3. Local dnsmasq resolver responsiveness on `127.0.0.1:53`.
4. Correctness of `/etc/resolv.conf`.
5. Existence of table `inet awg_bypass` and sets `bypass_v4` / `bypass_v6`.
6. Dynamic population of nftset upon domain resolution (e.g. `github.com`).
7. HTTPS accessibility of bypass domains (`github.com`, `nixos.org`).
8. Status of the AmneziaWG tunnel (`awg0`) and presence of active handshakes.
9. Outbound global internet routing through the full VPN tunnel.

### 3. Domain Bypass Mechanism Deep Test

Deep inspection and verification of the `dnsmasq` -> `nftset` -> `fwmark 51820` -> `table main` chain:

```bash
sudo ./tests/test-dnsmasq-bypass.sh github.com
```

---

## Output Structure `tests/<date>/`

Each execution of `diagnose-network.sh` creates a structured artifact directory:

```text
tests/<date>/
├── report.md                  # Markdown summary report with status check table
├── 01-system-info.log         # Kernel version, hostname, uptime, loaded modules
├── 02-interfaces.log          # ip link, ip addr, packet drop/error stats, nmcli
├── 03-routing.log             # ip rule, table main, table 51820, route get lookups
├── 04-dns.log                 # resolv.conf, dnsmasq configs, dig, getent hosts
├── 05-firewall-nftables.log   # nft list ruleset, awg_bypass sets, iptables -S
├── 06-sysctl.log              # rp_filter settings, ip_forward, forwarding
├── 07-services.log            # systemctl status and journalctl logs for all services
└── 08-connectivity.log        # awg show, ping, curl domain probes, public IP
```

---

## Comprehensive Command Reference (Manual Inspection)

When you need to manually inspect the machine's networking state:

### 1. Interfaces & Physical Layer
```bash
# List all interfaces, link state (UP/DOWN), MTU, and MAC addresses
ip -details link show

# All assigned IPv4 and IPv6 addresses
ip -brief addr show
ip -4 addr show
ip -6 addr show

# Packet errors, drops, and collisions per interface
ip -s link

# NetworkManager devices and active connection profiles
nmcli device status
nmcli connection show --active
```

### 2. Routing & Policy Routing (FIB)
```bash
# Policy routing rules (FIB):
# Shows rule precedence and lookup tables based on fwmark, suppress, etc.
ip -4 rule show
ip -6 rule show

# Main routing table (physical gateway, local Wi-Fi / Ethernet subnets)
ip -4 route show table main

# VPN routing table (awg-quick directs 0.0.0.0/0 to awg0 here)
ip -4 route show table 51820

# Query which interface and source IP the kernel will select:
# Without mark (routes to awg0):
ip route get 1.1.1.1
ip route get 140.82.121.4

# With bypass fwmark 51820 (routes via default physical gateway wlp1s0 / enp...):
ip route get 1.1.1.1 mark 51820
ip route get 140.82.121.4 mark 51820
```

### 3. DNS & Name Resolution
```bash
# Current system resolver configuration (should contain nameserver 127.0.0.1)
cat /etc/resolv.conf

# Query local dnsmasq resolver directly
dig @127.0.0.1 github.com +short

# Query upstream DNS directly bypassing the tunnel
dig @1.1.1.1 github.com +short

# Test via glibc getent (matches resolution behavior of curl, git, browsers)
getent hosts github.com
getent hosts nixos.org
```

### 4. Firewall & nftables
```bash
# Dump the complete active nftables ruleset
sudo nft list ruleset

# Inspect the bypass table
sudo nft list table inet awg_bypass

# Inspect IPs dynamically added by dnsmasq to the bypass sets
sudo nft list set inet awg_bypass bypass_v4
sudo nft list set inet awg_bypass bypass_v6

# Inspect legacy iptables rules (if firewall-iptables is active)
sudo iptables -S
sudo iptables -t nat -S
sudo iptables -t mangle -S
```

### 5. AmneziaWG / WireGuard
```bash
# Current tunnel interface status (public keys, endpoint, handshake, rx/tx bytes)
sudo awg show
sudo wg show

# Systemd tunnel service status and logs
systemctl status awg-quick-awg0.service --no-pager
journalctl -u awg-quick-awg0.service -n 50 --no-pager
```

### 6. System Services
```bash
# Status of NetworkManager, dnsmasq, and firewall services
systemctl status NetworkManager.service --no-pager
systemctl status dnsmasq.service --no-pager
systemctl status firewall.service --no-pager

# dnsmasq logs (check for permission issues when writing to nftset)
journalctl -u dnsmasq.service -n 50 --no-pager
```

### 7. Kernel Parameters (sysctl)
```bash
# Reverse path filter (rp_filter) settings:
# 0 = disabled, 1 = strict, 2 = loose
sysctl -a | grep -E '\.rp_filter'

# IPv4 packet forwarding
sysctl net.ipv4.ip_forward
```

---

## Network Architecture & Split Tunneling

### 1. Root Causes: Why Internet Broke With All Services Enabled
1. **Placeholder Keys in AmneziaWG Config**: `secrets/amnezia_for_awg.conf` contains published test keys. When `awg-quick-awg0` starts, `awg-quick` hijacks all traffic (`AllowedIPs = 0.0.0.0/0`) via `not fwmark 51820 lookup 51820`. If the tunnel endpoint is unreachable, all unexempted traffic enters a black hole.
2. **DNS Pollution in dnsmasq**: If NetworkManager pushes DHCP DNS servers (e.g., local router or unrouted 8.8.8.8) and `no-resolv` is missing, `dnsmasq` queries those servers without a bypass mark. Those queries enter the dead `awg0` tunnel, stalling DNS. With `no-resolv = true`, queries are dispatched **strictly** to `networking.bypass.dnsServers` (`1.1.1.1`, `1.0.0.1`), which are explicitly marked with `51820` and routed through the physical gateway.
3. **Reverse Path Filter Packet Drops (`rp_filter`)**: When bypass traffic leaves via `wlp1s0` with mark `51820`, return packets arrive on the physical interface. With strict `checkReversePath`, the kernel drops responses because the forward routing table points to `awg0`. Setting `checkReversePath = "loose"` resolves asymmetric return path drops.
4. **dnsmasq nftset Permissions**: `dnsmasq` drops privileges to an unprivileged user at startup. Adding resolved entries to nftables sets requires the `CAP_NET_ADMIN` capability.

### 2. How the Split Tunnel Works
```text
 Application (e.g. curl https://github.com)
     │
     ▼
 1. DNS Resolution -> 127.0.0.1:53 (dnsmasq)
     │
     ├─► dnsmasq sends query to 1.1.1.1
     │   (nftables rule: ip daddr 1.1.1.1 -> meta mark set 51820 -> routes via default gateway)
     │
     ├─► Resolved response received (e.g. 140.82.121.4)
     │   dnsmasq automatically executes:
     │   add element inet awg_bypass bypass_v4 { 140.82.121.4 }
     │
     ▼
 2. Connection to 140.82.121.4:443
     │
     ├─► nftables output chain (mangle):
     │   ip daddr @bypass_v4 -> meta mark set 51820
     │
     ├─► Policy Routing:
     │   not fwmark 51820 lookup 51820  (SKIPPED - mark matches!)
     │   lookup main                     (MATCHED -> routes via physical Wi-Fi gateway)
     │
     └─► nftables postrouting chain:
         meta mark 51820 masquerade -> SNAT to physical interface IP
```

Any domain not listed in the bypass configuration does not enter `@bypass_v4`, receives no fwmark, and routes securely inside the `awg0` VPN tunnel.
