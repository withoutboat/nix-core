#!/usr/bin/env bash
# ==============================================================================
# tests/diagnose-network.sh
# Exhaustive automated network diagnostics for NixOS (pc-th)
# Outputs all diagnostic logs and summary report to tests/<date>/
# ==============================================================================

set -u

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Determine script and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Target date / timestamp folder (default: YYYY-MM-DD_HH-MM-SS or passed as $1)
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
DATE_ONLY="$(date +%Y-%m-%d)"
TARGET_DIR="${1:-${REPO_ROOT}/tests/${TIMESTAMP}}"

mkdir -p "${TARGET_DIR}"

echo -e "${BOLD}${CYAN}===================================================================${NC}"
echo -e "${BOLD}${CYAN}   NixOS Network Diagnostic Collector & Deep Inspector             ${NC}"
echo -e "${BOLD}${CYAN}===================================================================${NC}"
echo -e "Timestamp : ${YELLOW}${TIMESTAMP}${NC}"
echo -e "Output Dir: ${YELLOW}${TARGET_DIR}${NC}"
echo ""

# Helper to run commands and redirect to file with section headers
run_probe() {
  local title="$1"
  local log_file="$2"
  local cmd="$3"

  echo "### [${title}] :: ${cmd}" >> "${log_file}"
  echo "--- Executed at $(date -u +'%Y-%m-%dT%H:%M:%SZ') ---" >> "${log_file}"
  eval "${cmd}" >> "${log_file}" 2>&1 || true
  echo -e "\n" >> "${log_file}"
}

# ------------------------------------------------------------------------------
# 1. System & Kernel Information
# ------------------------------------------------------------------------------
echo -e "${BLUE}[1/8] Collecting System & Kernel Info...${NC}"
SYS_LOG="${TARGET_DIR}/01-system-info.log"
run_probe "Hostname" "${SYS_LOG}" "hostname"
run_probe "Kernel Version" "${SYS_LOG}" "uname -a"
run_probe "Uptime & Load" "${SYS_LOG}" "uptime"
run_probe "Network Kernel Modules Loaded" "${SYS_LOG}" "lsmod | grep -E 'amnezia|wireguard|nft|ipt|tun'"

# ------------------------------------------------------------------------------
# 2. Interfaces & Physical Links
# ------------------------------------------------------------------------------
echo -e "${BLUE}[2/8] Collecting Interface Details & Statistics...${NC}"
IF_LOG="${TARGET_DIR}/02-interfaces.log"
run_probe "IP Link Detailed" "${IF_LOG}" "ip -details link show"
run_probe "IPv4 Addresses" "${IF_LOG}" "ip -4 addr show"
run_probe "IPv6 Addresses" "${IF_LOG}" "ip -6 addr show"
run_probe "Interface Packet Statistics" "${IF_LOG}" "ip -s link"
run_probe "NetworkManager Device Status" "${IF_LOG}" "nmcli device status"
run_probe "NetworkManager Active Connections" "${IF_LOG}" "nmcli connection show --active"

# ------------------------------------------------------------------------------
# 3. Routing Tables & Policy Routing Rules
# ------------------------------------------------------------------------------
echo -e "${BLUE}[3/8] Collecting Policy Routing & FIB Rules...${NC}"
ROUTE_LOG="${TARGET_DIR}/03-routing.log"
run_probe "IPv4 Rules (FIB Policy)" "${ROUTE_LOG}" "ip -4 rule show"
run_probe "IPv6 Rules (FIB Policy)" "${ROUTE_LOG}" "ip -6 rule show"
run_probe "Main Routing Table (IPv4)" "${ROUTE_LOG}" "ip -4 route show table main"
run_probe "VPN Routing Table 51820 (IPv4)" "${ROUTE_LOG}" "ip -4 route show table 51820"
run_probe "All IPv4 Routes" "${ROUTE_LOG}" "ip -4 route show table all"
run_probe "All IPv6 Routes" "${ROUTE_LOG}" "ip -6 route show table all"

# Route get probes
run_probe "Route Get Upstream DNS (1.1.1.1, default mark)" "${ROUTE_LOG}" "ip route get 1.1.1.1"
run_probe "Route Get Upstream DNS (1.1.1.1, mark 51820)" "${ROUTE_LOG}" "ip route get 1.1.1.1 mark 51820"
run_probe "Route Get GitHub (140.82.121.4, default mark)" "${ROUTE_LOG}" "ip route get 140.82.121.4"
run_probe "Route Get GitHub (140.82.121.4, mark 51820)" "${ROUTE_LOG}" "ip route get 140.82.121.4 mark 51820"
run_probe "Route Get Arbitrary Internet (8.8.8.8, default mark)" "${ROUTE_LOG}" "ip route get 8.8.8.8"

# ------------------------------------------------------------------------------
# 4. DNS Configuration & Resolution
# ------------------------------------------------------------------------------
echo -e "${BLUE}[4/8] Collecting DNS Configuration & Probing Resolvers...${NC}"
DNS_LOG="${TARGET_DIR}/04-dns.log"
run_probe "Resolv.conf Content" "${DNS_LOG}" "cat /etc/resolv.conf"
run_probe "Resolv.conf Symlink Target" "${DNS_LOG}" "ls -la /etc/resolv.conf"
run_probe "Dnsmasq Resolv File" "${DNS_LOG}" "[ -f /etc/dnsmasq-resolv.conf ] && cat /etc/dnsmasq-resolv.conf || echo 'Not present'"
run_probe "Dnsmasq Conf File" "${DNS_LOG}" "[ -f /etc/dnsmasq-conf.conf ] && cat /etc/dnsmasq-conf.conf || echo 'Not present'"
run_probe "Hosts File" "${DNS_LOG}" "cat /etc/hosts"

# Resolution probes
run_probe "DNS Dig @127.0.0.1 github.com" "${DNS_LOG}" "dig @127.0.0.1 github.com +short +timeout=3"
run_probe "DNS Dig @127.0.0.1 nixos.org" "${DNS_LOG}" "dig @127.0.0.1 nixos.org +short +timeout=3"
run_probe "DNS Dig @1.1.1.1 github.com (direct upstream)" "${DNS_LOG}" "dig @1.1.1.1 github.com +short +timeout=3"
run_probe "System Resolver getent github.com" "${DNS_LOG}" "getent hosts github.com"
run_probe "System Resolver getent nixos.org" "${DNS_LOG}" "getent hosts nixos.org"

# ------------------------------------------------------------------------------
# 5. Netfilter, nftables & Firewall
# ------------------------------------------------------------------------------
echo -e "${BLUE}[5/8] Collecting Netfilter, nftables & iptables Rules...${NC}"
NFT_LOG="${TARGET_DIR}/05-firewall-nftables.log"
run_probe "Full nftables Ruleset" "${NFT_LOG}" "nft list ruleset"
run_probe "Table inet awg_bypass" "${NFT_LOG}" "nft list table inet awg_bypass"
run_probe "Set inet awg_bypass bypass_v4" "${NFT_LOG}" "nft list set inet awg_bypass bypass_v4"
run_probe "Set inet awg_bypass bypass_v6" "${NFT_LOG}" "nft list set inet awg_bypass bypass_v6"
run_probe "iptables Filter Rules" "${NFT_LOG}" "iptables -S"
run_probe "iptables NAT Rules" "${NFT_LOG}" "iptables -t nat -S"
run_probe "iptables Mangle Rules" "${NFT_LOG}" "iptables -t mangle -S"

# ------------------------------------------------------------------------------
# 6. Sysctl Networking Parameters
# ------------------------------------------------------------------------------
echo -e "${BLUE}[6/8] Collecting Kernel Network Sysctls...${NC}"
SYSCTL_LOG="${TARGET_DIR}/06-sysctl.log"
run_probe "Reverse Path Filter (rp_filter) Settings" "${SYSCTL_LOG}" "sysctl -a | grep -E '\.rp_filter'"
run_probe "IP Forwarding Settings" "${SYSCTL_LOG}" "sysctl -a | grep -E '\.(ip_forward|forwarding)'"

# ------------------------------------------------------------------------------
# 7. Services & Systemd Units
# ------------------------------------------------------------------------------
echo -e "${BLUE}[7/8] Inspecting Systemd Units & Service Logs...${NC}"
SVC_LOG="${TARGET_DIR}/07-services.log"
run_probe "NetworkManager Status" "${SVC_LOG}" "systemctl status NetworkManager.service --no-pager"
run_probe "dnsmasq Status" "${SVC_LOG}" "systemctl status dnsmasq.service --no-pager"
run_probe "firewall Status" "${SVC_LOG}" "systemctl status firewall.service --no-pager"
run_probe "awg-quick Status" "${SVC_LOG}" "systemctl status 'awg-quick*' 'wg-quick*' --no-pager"
run_probe "Recent dnsmasq Journal Logs" "${SVC_LOG}" "journalctl -u dnsmasq.service -n 50 --no-pager"
run_probe "Recent awg-quick Journal Logs" "${SVC_LOG}" "journalctl -u 'awg-quick*' -n 50 --no-pager"
run_probe "Recent firewall Journal Logs" "${SVC_LOG}" "journalctl -u firewall.service -n 50 --no-pager"

# ------------------------------------------------------------------------------
# 8. Tunnel & End-to-End Connectivity Checks
# ------------------------------------------------------------------------------
echo -e "${BLUE}[8/8] Performing End-to-End Connectivity Probes...${NC}"
CONN_LOG="${TARGET_DIR}/08-connectivity.log"
run_probe "AmneziaWG / WireGuard Show" "${CONN_LOG}" "awg show || wg show"

# Gateway ping
DEFAULT_GW="$(ip route 2>/dev/null | awk '/default/ {print $3}' | head -n1)"
if [ -n "${DEFAULT_GW}" ]; then
  run_probe "Ping Default Gateway (${DEFAULT_GW})" "${CONN_LOG}" "ping -c 3 -W 2 ${DEFAULT_GW}"
fi

# Upstream DNS ping
run_probe "Ping Upstream DNS 1.1.1.1" "${CONN_LOG}" "ping -c 3 -W 2 1.1.1.1"
run_probe "Ping Upstream DNS 1.0.0.1" "${CONN_LOG}" "ping -c 3 -W 2 1.0.0.1"

# Bypass domain HTTP/HTTPS probes
run_probe "Curl https://github.com (Bypass domain)" "${CONN_LOG}" "curl -svo /dev/null --connect-timeout 5 https://github.com"
run_probe "Curl https://nixos.org (Bypass domain)" "${CONN_LOG}" "curl -svo /dev/null --connect-timeout 5 https://nixos.org"
run_probe "Curl Public IP (ifconfig.me)" "${CONN_LOG}" "curl -s --connect-timeout 5 https://ifconfig.me"

# Non-bypass domain probe (tests tunnel reachability)
run_probe "Curl https://google.com (Tunnel route)" "${CONN_LOG}" "curl -svo /dev/null --connect-timeout 5 https://google.com"

# ------------------------------------------------------------------------------
# Generate Markdown Summary Report
# ------------------------------------------------------------------------------
REPORT_FILE="${TARGET_DIR}/report.md"

GW_STATUS="❌ Unreachable"
if [ -n "${DEFAULT_GW}" ] && ping -c 1 -W 2 "${DEFAULT_GW}" >/dev/null 2>&1; then
  GW_STATUS="✅ Reachable (${DEFAULT_GW})"
fi

DNS_PING_STATUS="❌ Unreachable"
if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
  DNS_PING_STATUS="✅ Reachable"
fi

DNSMASQ_STATUS="❌ Failing"
if dig @127.0.0.1 github.com +short +timeout=2 >/dev/null 2>&1; then
  DNSMASQ_STATUS="✅ Resolving"
fi

GITHUB_STATUS="❌ Failed"
if curl -s --connect-timeout 3 https://github.com >/dev/null 2>&1; then
  GITHUB_STATUS="✅ Connected"
fi

NIXOS_STATUS="❌ Failed"
if curl -s --connect-timeout 3 https://nixos.org >/dev/null 2>&1; then
  NIXOS_STATUS="✅ Connected"
fi

GOOGLE_STATUS="⚠️ Down/Unreachable"
if curl -s --connect-timeout 3 https://google.com >/dev/null 2>&1; then
  GOOGLE_STATUS="✅ Connected"
fi

cat << EOF > "${REPORT_FILE}"
# Network Diagnostics Report

- **Date / Time**: $(date -u +'%Y-%m-%d %H:%M:%S UTC')
- **Hostname**: $(hostname 2>/dev/null || echo "unknown")
- **Kernel**: $(uname -r 2>/dev/null || echo "unknown")
- **Log Directory**: \`${TARGET_DIR}\`

---

## Quick Status Summary

| Check | Result | Details |
|---|---|---|
| **Default Gateway** | ${GW_STATUS} | Physical LAN gateway connection |
| **Upstream DNS (1.1.1.1)** | ${DNS_PING_STATUS} | Direct bypass ICMP reachability |
| **Local dnsmasq (127.0.0.1)** | ${DNSMASQ_STATUS} | Port 53 resolution via dnsmasq |
| **Domain Bypass (github.com)** | ${GITHUB_STATUS} | HTTPS connectivity to bypass domain |
| **Domain Bypass (nixos.org)** | ${NIXOS_STATUS} | HTTPS connectivity to bypass domain |
| **Full Tunnel Route (google.com)** | ${GOOGLE_STATUS} | Connectivity through VPN tunnel |

---

## Key Diagnostics Overview

### 1. Interfaces
\`\`\`text
$(ip -brief addr show 2>/dev/null || echo "ip command unavailable")
\`\`\`

### 2. Policy Routing Rules
\`\`\`text
$(ip rule show 2>/dev/null || echo "ip rule unavailable")
\`\`\`

### 3. DNS Configuration (\`/etc/resolv.conf\`)
\`\`\`text
$(cat /etc/resolv.conf 2>/dev/null || echo "resolv.conf unreadable")
\`\`\`

### 4. nftables Bypass Sets Status
\`\`\`text
$(nft list set inet awg_bypass bypass_v4 2>/dev/null || echo "Set inet awg_bypass bypass_v4 not found or nftables inaccessible")
\`\`\`

### 5. AmneziaWG Tunnel Status
\`\`\`text
$(awg show 2>/dev/null || wg show 2>/dev/null || echo "No active WireGuard / AmneziaWG interface")
\`\`\`

---

## Log Artifacts

- [01-system-info.log](01-system-info.log)
- [02-interfaces.log](02-interfaces.log)
- [03-routing.log](03-routing.log)
- [04-dns.log](04-dns.log)
- [05-firewall-nftables.log](05-firewall-nftables.log)
- [06-sysctl.log](06-sysctl.log)
- [07-services.log](07-services.log)
- [08-connectivity.log](08-connectivity.log)

EOF

# Create pointer to latest
rm -f "${REPO_ROOT}/tests/latest" 2>/dev/null || true
ln -s "${TARGET_DIR}" "${REPO_ROOT}/tests/latest" 2>/dev/null || true

echo ""
echo -e "${BOLD}${GREEN}Diagnostics complete!${NC}"
echo -e "Report generated: ${BOLD}${YELLOW}${REPORT_FILE}${NC}"
echo -e "Symlink created:  ${BOLD}${YELLOW}${REPO_ROOT}/tests/latest${NC}"
echo ""
cat "${REPORT_FILE}"
