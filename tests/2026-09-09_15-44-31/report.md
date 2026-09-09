# Network Diagnostics Report

- **Date / Time**: 2026-09-09 15:45:01 UTC
- **Hostname**: pc-th
- **Kernel**: 6.18.49
- **Log Directory**: `/home/withoutboat/nix-core/tests/2026-09-09_15-44-31`

---

## Quick Status Summary

| Check | Result | Details |
|---|---|---|
| **Default Gateway** | ✅ Reachable (192.168.31.1) | Physical LAN gateway connection |
| **Upstream DNS (1.1.1.1)** | ✅ Reachable | Direct bypass ICMP reachability |
| **Local dnsmasq (127.0.0.1)** | ✅ Resolving | Port 53 resolution via dnsmasq |
| **Domain Bypass (github.com)** | ✅ Connected | HTTPS connectivity to bypass domain |
| **Domain Bypass (nixos.org)** | ✅ Connected | HTTPS connectivity to bypass domain |
| **Full Tunnel Route (google.com)** | ⚠️ Down/Unreachable | Connectivity through VPN tunnel |

---

## Key Diagnostics Overview

### 1. Interfaces
```text
lo               UNKNOWN        127.0.0.1/8 ::1/128 
enp2s0           DOWN           
wlo1             UP             192.168.31.169/24 fe80::c257:6193:c419:732c/64 
awg0             UNKNOWN        10.8.1.11/32 
```

### 2. Policy Routing Rules
```text
0:	from all lookup local
32764:	from all lookup main suppress_prefixlength 0
32765:	not from all fwmark 0xca6c lookup 51820
32766:	from all lookup main
32767:	from all lookup default
```

### 3. DNS Configuration (`/etc/resolv.conf`)
```text
nameserver 1.1.1.1
```

### 4. nftables Bypass Sets Status
```text
table inet awg_bypass {
	set bypass_v4 {
		type ipv4_addr
		timeout 1h
		elements = { 75.2.60.5 expires 59m29s941ms,
			     99.83.231.61 expires 59m29s945ms,
			     140.82.121.3 expires 59m29s887ms }
	}
}
```

### 5. AmneziaWG Tunnel Status
```text
interface: awg0
  public key: 7Q9Jp0QvXu2tu6mog635EaVz1IYbMt9pdXgiFe61vH0=
  private key: (hidden)
  listening port: 45790
  fwmark: 0xca6c
  jc: 5
  jmin: 10
  jmax: 50
  s1: 69
  s2: 132
  s3: 6
  s4: 5
  h1: 117028949-1005410162
  h2: 1231176932-1803586643
  h3: 1890197938-2064918576
  h4: 2126864087-2138021283
  i1: <b 0x084481800001000300000000077469636b65747306776964676574096b696e6f706f69736b0272750000010001c00c0005000100000039001806776964676574077469636b6574730679616e646578c025c0390005000100000039002b1765787465726e616c2d7469636b6574732d776964676574066166697368610679616e646578036e657400c05d000100010000001c000457fafe25>
  random trailers: off
  disable cookies: off

peer: 2c1o9//w190B6DvPgsrJUr2+3wonW3NzNUojYxjMkkg=
  preshared key: (hidden)
  endpoint: 144.31.154.165:46399
  allowed ips: 0.0.0.0/0, ::/0
  transfer: 0 B received, 6.04 KiB sent
  persistent keepalive: 25
```

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

