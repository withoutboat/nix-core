#!/usr/bin/env bash
# ==============================================================================
# tests/check-connectivity.sh
# Fast automated network connectivity and bypass assertion checker.
# Verifies each network component and reports PASS / WARN / FAIL.
# ==============================================================================

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

report_pass() {
  local test_name="$1"
  local details="$2"
  echo -e " [ ${GREEN}PASS${NC} ] ${BOLD}${test_name}${NC} - ${details}"
  PASS_COUNT=$((PASS_COUNT + 1))
}

report_warn() {
  local test_name="$1"
  local details="$2"
  echo -e " [ ${YELLOW}WARN${NC} ] ${BOLD}${test_name}${NC} - ${YELLOW}${details}${NC}"
  WARN_COUNT=$((WARN_COUNT + 1))
}

report_fail() {
  local test_name="$1"
  local details="$2"
  echo -e " [ ${RED}FAIL${NC} ] ${BOLD}${test_name}${NC} - ${RED}${details}${NC}"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

echo -e "${BOLD}${BLUE}===================================================================${NC}"
echo -e "${BOLD}${BLUE}   Automated Network & Split-Tunnel Bypass Verification            ${NC}"
echo -e "${BOLD}${BLUE}===================================================================${NC}"
echo ""

# 1. Physical / LAN Gateway Connectivity
DEFAULT_GW="$(ip route 2>/dev/null | awk '/default/ {print $3}' | head -n1)"
if [ -n "${DEFAULT_GW}" ]; then
  if ping -c 2 -W 2 "${DEFAULT_GW}" >/dev/null 2>&1; then
    report_pass "Physical Gateway" "Default gateway (${DEFAULT_GW}) responds to ping"
  else
    report_fail "Physical Gateway" "Default gateway (${DEFAULT_GW}) unreachable via ping"
  fi
else
  report_fail "Physical Gateway" "No default route found in system routing table"
fi

# 2. Upstream DNS Reachability (ICMP)
if ping -c 2 -W 2 1.1.1.1 >/dev/null 2>&1; then
  report_pass "Upstream DNS ICMP" "1.1.1.1 is reachable directly via default gateway"
else
  report_fail "Upstream DNS ICMP" "1.1.1.1 unreachable. Firewall or routing may block traffic"
fi

# 3. Local dnsmasq Resolver (127.0.0.1:53)
if dig @127.0.0.1 1.1.1.1 +short +timeout=2 >/dev/null 2>&1 || dig @127.0.0.1 github.com +short +timeout=2 | grep -qE '^[0-9]+\.[0-9]+'; then
  report_pass "Local dnsmasq" "dnsmasq on 127.0.0.1:53 is successfully answering queries"
else
  report_fail "Local dnsmasq" "dnsmasq failed to resolve query on 127.0.0.1:53"
fi

# 4. System Resolver (/etc/resolv.conf)
RESOLV_NS="$(awk '/^nameserver/ {print $2}' /etc/resolv.conf 2>/dev/null | head -n1)"
if [ "${RESOLV_NS}" = "127.0.0.1" ]; then
  report_pass "System Resolver Config" "/etc/resolv.conf correctly points to local resolver (127.0.0.1)"
else
  report_warn "System Resolver Config" "/etc/resolv.conf points to '${RESOLV_NS:-none}' instead of 127.0.0.1"
fi

# 5. nftables Bypass Table & Sets
if nft list table inet awg_bypass >/dev/null 2>&1; then
  report_pass "nftables Bypass Table" "Table 'inet awg_bypass' exists in ruleset"
  
  if nft list set inet awg_bypass bypass_v4 >/dev/null 2>&1; then
    SET_ELEMENTS="$(nft list set inet awg_bypass bypass_v4 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | wc -l)"
    report_pass "nftables IPv4 Bypass Set" "Set 'bypass_v4' exists (currently contains ${SET_ELEMENTS} dynamic IP entries)"
  else
    report_fail "nftables IPv4 Bypass Set" "Set 'bypass_v4' not found in table 'inet awg_bypass'"
  fi
else
  report_warn "nftables Bypass Table" "Table 'inet awg_bypass' not found. Bypass rules might be inactive"
fi

# 6. Bypass Domain Resolution & nftset Population
RESOLVED_BYPASS="$(dig @127.0.0.1 nixos.org +short +timeout=3 2>/dev/null | grep -E '^[0-9]+\.[0-9]+' | head -n1)"
if [ -n "${RESOLVED_BYPASS}" ]; then
  report_pass "Bypass Domain Resolution" "nixos.org resolved to ${RESOLVED_BYPASS}"
  
  # Check if IP was added to nftables set
  if nft list set inet awg_bypass bypass_v4 2>/dev/null | grep -q "${RESOLVED_BYPASS}"; then
    report_pass "Dynamic nftset Population" "IP ${RESOLVED_BYPASS} was successfully added to @bypass_v4 by dnsmasq"
  else
    report_warn "Dynamic nftset Population" "IP ${RESOLVED_BYPASS} was NOT found in @bypass_v4. Check dnsmasq CAP_NET_ADMIN"
  fi
else
  report_fail "Bypass Domain Resolution" "Failed to resolve nixos.org via local resolver"
fi

# 7. Bypass Domain HTTP/HTTPS Connectivity
if curl -s -I --connect-timeout 4 https://github.com >/dev/null 2>&1; then
  report_pass "Bypass HTTPS Traffic" "Successfully connected to https://github.com"
else
  report_fail "Bypass HTTPS Traffic" "Failed to connect to https://github.com (timeout or connection refused)"
fi

if curl -s -I --connect-timeout 4 https://nixos.org >/dev/null 2>&1; then
  report_pass "NixOS Cache HTTPS Traffic" "Successfully connected to https://nixos.org"
else
  report_fail "NixOS Cache HTTPS Traffic" "Failed to connect to https://nixos.org"
fi

# 8. VPN Server Endpoint Reachability (Physical Interface)
AWG_ENDPOINT="$(awg show awg0 endpoints 2>/dev/null | awk '{print $2}' | cut -d: -f1)"
PHYS_IF="$(ip route show table main 2>/dev/null | awk '/default/ {print $5}' | head -n1)"
if [ -n "${AWG_ENDPOINT}" ]; then
  if [ -n "${PHYS_IF}" ] && ping -c 2 -W 2 -I "${PHYS_IF}" "${AWG_ENDPOINT}" >/dev/null 2>&1; then
    report_pass "VPN Endpoint Link" "Endpoint ${AWG_ENDPOINT} is reachable directly via ${PHYS_IF}"
  else
    report_warn "VPN Endpoint Link" "Endpoint ${AWG_ENDPOINT} did not respond to ICMP ping via ${PHYS_IF:-default} (host may block ping)"
  fi
fi

# 9. AmneziaWG Tunnel Status & Full Tunnel Verification
AWG_IF="$(ip link show dev awg0 2>/dev/null || true)"
if [ -n "${AWG_IF}" ]; then
  AWG_HANDSHAKE="$(awg show awg0 latest-handshakes 2>/dev/null || wg show awg0 latest-handshakes 2>/dev/null || true)"
  AWG_TS="$(echo "${AWG_HANDSHAKE}" | awk '{print $2}' | head -n1)"
  
  if [ -n "${AWG_TS}" ] && [ "${AWG_TS}" -gt 0 ] 2>/dev/null; then
    report_pass "AmneziaWG Handshake" "Interface awg0 has active handshake (timestamp: ${AWG_TS})"
  else
    report_warn "AmneziaWG Handshake" "Interface awg0 exists but has no active handshake (test keys or server down)"
  fi

  # Test full tunnel routing
  if curl -s -I --connect-timeout 4 https://google.com >/dev/null 2>&1; then
    report_pass "Full Tunnel Egress" "Successfully routed non-bypass traffic (https://google.com)"
  else
    report_warn "Full Tunnel Egress" "Non-bypass traffic (https://google.com) is down (expected if VPN server is unreachable)"
  fi
else
  report_warn "AmneziaWG Tunnel" "Interface awg0 is not active"
fi

echo ""
echo -e "${BOLD}Summary: ${GREEN}${PASS_COUNT} Passed${NC}, ${YELLOW}${WARN_COUNT} Warnings${NC}, ${RED}${FAIL_COUNT} Failed${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
  echo -e "${BOLD}${GREEN}Network checks passed successfully!${NC}"
  exit 0
else
  echo -e "${BOLD}${RED}Some network checks failed. Run tests/diagnose-network.sh for full debug dump.${NC}"
  exit 1
fi
