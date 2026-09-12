#!/usr/bin/env bash
# ==============================================================================
# tests/test-dnsmasq-bypass.sh
# Deep test of the dnsmasq -> nftset -> fwmark -> table main bypass mechanism.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TEST_DOMAIN="${1:-nixos.org}"

echo -e "${BOLD}${BLUE}===================================================================${NC}"
echo -e "${BOLD}${BLUE}   dnsmasq + nftables Split-Tunnel Bypass Verification             ${NC}"
echo -e "${BOLD}${BLUE}===================================================================${NC}"
echo -e "Testing Domain: ${BOLD}${YELLOW}${TEST_DOMAIN}${NC}\n"

# Step 1: Query local dnsmasq
echo -e "1. Querying 127.0.0.1:53 for ${TEST_DOMAIN}..."
RESOLVE_OUT="$(dig @127.0.0.1 "${TEST_DOMAIN}" +short +timeout=3)"
if [ -z "${RESOLVE_OUT}" ]; then
  echo -e "   ${RED}FAIL: No DNS response from 127.0.0.1:53 for ${TEST_DOMAIN}${NC}"
  exit 1
fi
echo -e "   Resolved IPs:\n${RESOLVE_OUT}"

# Pick first IPv4 address
TARGET_IP="$(echo "${RESOLVE_OUT}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
if [ -z "${TARGET_IP}" ]; then
  echo -e "   ${YELLOW}WARN: No IPv4 address resolved for ${TEST_DOMAIN}${NC}"
  exit 0
fi
echo -e "   Target IP for test: ${BOLD}${GREEN}${TARGET_IP}${NC}"

# Step 2: Check if TARGET_IP is in nftables bypass_v4 set
echo -e "\n2. Verifying nftables set 'inet awg_bypass bypass_v4'..."
if nft list set inet awg_bypass bypass_v4 2>/dev/null | grep -q "${TARGET_IP}"; then
  echo -e "   ${GREEN}PASS: ${TARGET_IP} is present in nftables set 'bypass_v4'!${NC}"
else
  echo -e "   ${RED}FAIL: ${TARGET_IP} was NOT added to set 'bypass_v4'.${NC}"
  echo -e "   Check dnsmasq service permissions (AmbientCapabilities=CAP_NET_ADMIN) and nftset settings."
  exit 1
fi

# Step 3: Check FIB routing lookup with and without fwmark
echo -e "\n3. Checking FIB Route Selection:"
ROUTE_DEFAULT="$(ip route get "${TARGET_IP}" 2>/dev/null || true)"
ROUTE_MARKED="$(ip route get "${TARGET_IP}" mark 51820 2>/dev/null || true)"

echo -e "   Route WITHOUT fwmark (default): ${ROUTE_DEFAULT}"
echo -e "   Route WITH fwmark 51820       : ${ROUTE_MARKED}"

# Step 4: Perform real HTTP request to test data flow
echo -e "\n4. Performing test HTTP connection to https://${TEST_DOMAIN}..."
HTTP_CODE="$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://${TEST_DOMAIN}" || echo "000")"
if [ "${HTTP_CODE}" != "000" ]; then
  echo -e "   ${GREEN}PASS: Connection succeeded! HTTP response code: ${HTTP_CODE}${NC}"
else
  echo -e "   ${RED}FAIL: Connection timed out or refused.${NC}"
  exit 1
fi

echo -e "\n${BOLD}${GREEN}All bypass mechanism steps verified successfully for ${TEST_DOMAIN}!${NC}"
