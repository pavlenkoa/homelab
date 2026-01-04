# OrbStack Cross-Node Networking

## Problem

OrbStack VM has an internal IP (192.168.139.81) that's not routable from the LAN. Cilium uses this IP for VXLAN tunneling, so Raspberry Pi can't reach pods on macmini.

```
macmini (OrbStack VM)     raspberrypi
├─ Internal: 192.168.139.81    ├─ LAN: 192.168.88.3
├─ LAN (via OrbStack): 192.168.88.2
└─ Cilium tunnel endpoint: 192.168.139.81  ← RPi can't reach this
```

## Solution

MikroTik router NAT rules redirect traffic destined for the VM's internal IP to the Mac's LAN IP.

### NAT Rules (wroclaw-router)

```bash
# Destination NAT: rewrite 192.168.139.81 → 192.168.88.2
/ip firewall nat add chain=dstnat dst-address=192.168.139.81 \
  action=dst-nat to-addresses=192.168.88.2 \
  comment="OrbStack VM internal IP to Mac LAN IP"

# Source NAT: masquerade so replies go through router
/ip firewall nat add chain=srcnat src-address=192.168.88.3 dst-address=192.168.88.2 \
  action=masquerade \
  comment="Force replies through router for OrbStack NAT"
```

### Why srcnat is needed

Without srcnat, the reply path is asymmetric:
1. RPi → 192.168.139.81 → router dst-nat → 192.168.88.2 (Mac)
2. Mac replies directly to RPi (same LAN), bypassing router
3. RPi sees reply from 192.168.88.2, but expected 192.168.139.81 → drops packet

With srcnat masquerade:
1. RPi → router (src becomes router IP) → Mac
2. Mac replies to router → router reverses NAT → RPi
3. RPi sees reply from 192.168.139.81 (original destination) → accepts

## Current State

| Feature | Status |
|---------|--------|
| Pod-to-pod cross-node | Works (VXLAN via UDP 8472) |
| Cilium health (endpoints) | Works |
| Cilium health (node) | Partial - HTTP to node:4240 fails |

### Why node health fails

Cilium health daemon binds to `192.168.139.81:4240`, not `0.0.0.0:4240`. OrbStack only auto-forwards ports bound to 0.0.0.0, so TCP 4240 isn't forwarded to the VM.

Result: `cilium status` shows "1/2 reachable" from RPi's perspective. This is cosmetic - actual pod networking works.

## OrbStack Port Forwarding

OrbStack automatically forwards these ports from Mac LAN to VM:
- UDP 8472 (VXLAN) - bound to 0.0.0.0 in VM
- TCP 80, 443 (ingress) - via hostNetwork
- TCP 6443 (k8s API)

Not forwarded:
- TCP 4240 (Cilium health) - bound to specific IP, not 0.0.0.0
