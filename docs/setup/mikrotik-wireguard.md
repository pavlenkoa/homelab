# WireGuard CGNAT Bypass Setup - MikroTik

A focused guide for setting up WireGuard tunnels between a static IP location and a CGNAT location, enabling services behind CGNAT to be accessible from the internet.

## Scenario

- **Kyiv**: MikroTik router with static public IP
- **Wrocław**: MikroTik router behind CGNAT  
- **Goal**: Route external traffic through Kyiv to reach services in Wrocław

## Network Planning

```
Kyiv LAN:          192.168.1.0/24
Wrocław LAN:       192.168.88.0/24  
WireGuard Tunnel:  10.77.88.0/30

Additional Tunnels:
Kyiv ↔ Oracle:     10.66.77.0/30
Wrocław ↔ Oracle:  10.88.99.0/30
```

## Part 1: Kyiv Router (Static IP Side)

### WireGuard Interface Setup

```bash
# Create WireGuard interface
/interface wireguard add name=to-wroclaw listen-port=12345

# Generate and set private key (keep this secure!)
/interface wireguard set to-wroclaw private-key="[GENERATED_PRIVATE_KEY]"

# Assign tunnel IP
/ip address add address=10.77.88.1/30 interface=to-wroclaw
```

### Add Wrocław as Peer

```bash
# Add peer configuration (replace with Wrocław's public key)
/interface wireguard peers add interface=to-wroclaw \
    public-key="[WROCLAW_PUBLIC_KEY]" \
    allowed-address=10.77.88.2/32,192.168.88.0/24 \
    comment="Wroclaw location"
```

### Routing to Wrocław

```bash
# Route Wrocław LAN traffic via tunnel
/ip route add dst-address=192.168.88.0/24 gateway=10.77.88.2
```

### NAT Rules for External Access

```bash
# DSTNAT: External traffic to Wrocław services (Mac Mini)
/ip firewall nat add chain=dstnat action=dst-nat \
    to-addresses=192.168.88.2 to-ports=443 protocol=tcp \
    dst-port=443 \
    comment="Forward HTTPS to Wroclaw Mac Mini"

# Don't NAT inter-LAN traffic
/ip firewall nat add chain=srcnat action=accept \
    src-address=192.168.88.0/24 dst-address=192.168.1.0/24 \
    comment="Skip NAT for LAN-to-LAN"

/ip firewall nat add chain=srcnat action=accept \
    src-address=192.168.1.0/24 dst-address=192.168.88.0/24 \
    comment="Skip NAT for LAN-to-LAN"
```

### Firewall Rules

```bash
# Allow WireGuard handshake
/ip firewall filter add chain=input action=accept \
    protocol=udp dst-port=12345 \
    comment="Allow WireGuard handshake"

# Allow tunnel traffic
/ip firewall filter add chain=forward action=accept \
    in-interface=to-wroclaw \
    comment="Allow traffic from tunnel"

/ip firewall filter add chain=forward action=accept \
    out-interface=to-wroclaw \
    comment="Allow traffic to tunnel"
```

## Part 2: Wrocław Router (CGNAT Side)

### WireGuard Interface Setup

```bash
# Create WireGuard interface  
/interface wireguard add name=to-kyiv listen-port=54321

# Set private key
/interface wireguard set to-kyiv private-key="[GENERATED_PRIVATE_KEY]"

# Assign tunnel IP
/ip address add address=10.77.88.2/30 interface=to-kyiv
```

### Add Kyiv as Peer

```bash
# Add peer with Kyiv's public IP and public key
/interface wireguard peers add interface=to-kyiv \
    public-key="[KYIV_PUBLIC_KEY]" \
    endpoint-address=[KYIV_PUBLIC_IP] \
    endpoint-port=12345 \
    allowed-address=10.77.88.1/32,192.168.1.0/24 \
    persistent-keepalive=25s \
    comment="Kyiv location"
```

### Routing to Kyiv

```bash
# Route Kyiv LAN via tunnel
/ip route add dst-address=192.168.1.0/24 gateway=10.77.88.1
```

### Policy Routing for Return Path

```bash
# Create routing table for external traffic
/routing table add name=via-kyiv fib

# Route marked traffic via Kyiv
/ip route add dst-address=0.0.0.0/0 gateway=10.77.88.1 \
    routing-table=via-kyiv
```

### Mangle Rules for Connection Tracking

```bash
# Mark connections coming from Kyiv tunnel
/ip firewall mangle add chain=prerouting \
    action=mark-connection new-connection-mark=from-kyiv \
    passthrough=no dst-address=192.168.88.2 \
    in-interface=to-kyiv \
    comment="Mark external connections"

# Route marked connections back via Kyiv  
/ip firewall mangle add chain=prerouting \
    action=mark-routing new-routing-mark=via-kyiv \
    passthrough=no connection-mark=from-kyiv \
    comment="Route external traffic back via Kyiv"
```

### NAT Rules

```bash
# Don't NAT tunnel traffic
/ip firewall nat add chain=srcnat action=accept \
    src-address=192.168.88.0/24 out-interface=to-kyiv \
    comment="Skip NAT for tunnel traffic"
```

### Firewall Rules

```bash
# Allow tunnel traffic
/ip firewall filter add chain=forward action=accept \
    in-interface=to-kyiv \
    comment="Allow traffic from Kyiv"

/ip firewall filter add chain=forward action=accept \
    out-interface=to-kyiv \
    comment="Allow traffic to Kyiv"
```

## Part 3: Testing

### Basic Connectivity

```bash
# Test tunnel connectivity
# From Kyiv:
/ping 10.77.88.2

# From Wrocław:  
/ping 10.77.88.1
```

### Cross-LAN Connectivity

```bash
# From Kyiv, test Wrocław LAN (Mac Mini)
/ping 192.168.88.2

# From Wrocław, test Kyiv LAN (Raspberry Pi)
/ping 192.168.1.2
```

### Monitor Tunnel Status

```bash
# Check peer status and traffic
/interface wireguard peers print
```

## Traffic Flow Summary

### External Request Flow
```
Internet → Kyiv Public IP:443 
       → DSTNAT to 192.168.88.2:443
       → Route via WireGuard tunnel (10.77.88.0/30)
       → Wrocław receives and forwards to Mac Mini
       → Mangle marks connection  
       → Forward to service
```

### Return Traffic Flow
```
Mac Mini Service → Mangle routes via Kyiv table
                 → Tunnel back to Kyiv (10.77.88.1)
                 → Normal routing to internet
```

## Key Points

1. **Keepalive**: Essential for CGNAT (25s recommended)
2. **Policy Routing**: Ensures return traffic uses same path
3. **Connection Marking**: Tracks external vs internal traffic  
4. **NAT Exemption**: Don't NAT tunnel traffic between LANs
5. **Return Path**: Policy routing ensures responses use correct path

This setup allows services behind CGNAT to be accessible while maintaining proper traffic flow and security.

## Part 4: Oracle Cloud Integration

The homelab extends to Oracle Cloud with additional WireGuard tunnels for centralized monitoring.

### Additional Tunnel Networks

```bash
# Kyiv ↔ Oracle tunnel
Kyiv tunnel IP:    10.66.77.1/30
Oracle tunnel IP:  10.66.77.2/30

# Wrocław ↔ Oracle tunnel  
Wrocław tunnel IP: 10.88.99.1/30
Oracle tunnel IP:  10.88.99.2/30
```

### Oracle VM WireGuard Setup

```bash
# Create interfaces for both tunnels
/interface wireguard add name=to-kyiv listen-port=56789
/interface wireguard add name=to-wroclaw listen-port=56790

# Assign tunnel IPs
/ip address add address=10.66.77.2/30 interface=to-kyiv
/ip address add address=10.88.99.2/30 interface=to-wroclaw

# Add peers (replace with actual public keys and endpoints)
/interface wireguard peers add interface=to-kyiv \
    public-key="[KYIV_PUBLIC_KEY]" \
    endpoint-address=[KYIV_PUBLIC_IP] \
    endpoint-port=56789 \
    allowed-address=10.66.77.1/32,192.168.1.0/24

/interface wireguard peers add interface=to-wroclaw \
    public-key="[WROCLAW_PUBLIC_KEY]" \
    endpoint-address=[KYIV_PUBLIC_IP] \
    endpoint-port=56790 \
    allowed-address=10.88.99.1/32,192.168.88.0/24 \
    persistent-keepalive=25s
```

### Routes for Multi-Site Connectivity

```bash
# Route to reach both LANs
/ip route add dst-address=192.168.1.0/24 gateway=10.66.77.1
/ip route add dst-address=192.168.88.0/24 gateway=10.88.99.1
```

This creates a hub-and-spoke topology with Oracle Cloud as a central monitoring hub.