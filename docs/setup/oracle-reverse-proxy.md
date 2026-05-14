# Oracle Cloud Reverse Proxy

Expose HTTPS services behind CGNAT via an Oracle Cloud Free Tier VM as an L4 forwarder. TLS terminates in the cluster (kgateway/Envoy with cert-manager); Oracle just DNATs `:443` over WireGuard.

## Scenario

- **Oracle VM**: public IP, WireGuard peer to Wrocław.
- **Wrocław**: MikroTik behind CGNAT, hosts the target service on `192.168.88.2:443`.
- **Goal**: route external HTTPS traffic via Cloudflare → Oracle → tunnel → Wrocław, preserving original client IP (no `MASQUERADE`).

## Network Planning

```
Oracle tunnel IP:       10.88.99.1/30
Wrocław tunnel IP:      10.88.99.2/30
Target service:         192.168.88.2:443
Cloudflare proxied DNS: orange-cloud, A record → Oracle public IP
```

The WireGuard tunnel itself is set up per [`mikrotik-wireguard.md`](./mikrotik-wireguard.md) Part 4.

## Part 1: OCI Security List

Ingress rules (egress = allow all):

| Source | Proto | Port | Purpose |
|---|---|---|---|
| Cloudflare IPv4 ranges | TCP | 443 | HTTPS via CF |
| Cloudflare IPv4 ranges | TCP | 80 | HTTP (ACME / redirect) |
| `[WROCLAW_WAN]/32` | UDP | 51820 | WireGuard handshake |
| `[WROCLAW_WAN]/32` | TCP | 22 | SSH |
| `0.0.0.0/0` | ICMP | 3,4 | PMTU discovery |

Cloudflare IPv4 ranges (sync with https://www.cloudflare.com/ips-v4):

```
173.245.48.0/20   103.21.244.0/22   103.22.200.0/22   103.31.4.0/22
141.101.64.0/18   108.162.192.0/18  190.93.240.0/20   188.114.96.0/20
197.234.240.0/22  198.41.128.0/17   162.158.0.0/15    104.16.0.0/13
104.24.0.0/14     172.64.0.0/13     131.0.72.0/22
```

## Part 2: Oracle VM (iptables)

WireGuard interface `wg0`, tunnel IP `10.88.99.1/30`, peer Wrocław `10.88.99.2`.

```bash
# DNAT public:443 → target service
iptables -t nat -A PREROUTING -i enp0s6 -p tcp --dport 443 \
    -j DNAT --to 192.168.88.2:443

# FORWARD: only tcp/443 between WAN and tunnel
iptables -I FORWARD 1 -i enp0s6 -o wg0 -d 192.168.88.2 -p tcp --dport 443 \
    -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT

iptables -I FORWARD 2 -i wg0 -o enp0s6 -s 192.168.88.2 -p tcp --sport 443 \
    -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```

Persist:

```bash
iptables-save > /etc/iptables/rules.v4
systemctl enable iptables
```

No `MASQUERADE` — conntrack reverses the DNAT automatically and preserves the original Cloudflare source IP for `X-Forwarded-For`.

## Part 3: Oracle WireGuard Peer

`/etc/wireguard/wg0.conf`:

```ini
[Interface]
PrivateKey = [ORACLE_PRIVATE_KEY]
Address    = 10.88.99.1/30
ListenPort = 51820

[Peer]
PublicKey    = [WROCLAW_PUBLIC_KEY]
PresharedKey = [PSK]
AllowedIPs   = 10.88.99.2/32, 192.168.88.2/32
```

## Part 4: Wrocław WireGuard Peer

Interface `wroclaw-oracle-tunnel`, address `10.88.99.2/30`. `allowed-address` must include Cloudflare ranges because DNAT preserves the original CF source on inbound packets:

```bash
/interface wireguard peers add interface=wroclaw-oracle-tunnel \
    name=Oracle-VM \
    public-key="[ORACLE_PUBLIC_KEY]" \
    preshared-key="[PSK]" \
    endpoint-address=[ORACLE_PUBLIC_IP] \
    endpoint-port=51820 \
    persistent-keepalive=25s \
    allowed-address=10.88.99.1/32,192.168.88.2/32,10.0.0.0/24,\
173.245.48.0/20,103.21.244.0/22,103.22.200.0/22,103.31.4.0/22,\
141.101.64.0/18,108.162.192.0/18,190.93.240.0/20,188.114.96.0/20,\
197.234.240.0/22,198.41.128.0/17,162.158.0.0/15,104.16.0.0/13,\
104.24.0.0/14,172.64.0.0/13,131.0.72.0/22
```

## Part 5: Wrocław Mangle (Return Path)

External connections returning via Oracle need policy routing back through the same tunnel:

```bash
/routing table add name=via-oracle fib

/ip route add dst-address=0.0.0.0/0 gateway=10.88.99.1 \
    routing-table=via-oracle

/ip firewall mangle add chain=prerouting \
    action=mark-connection new-connection-mark=via-oracle \
    in-interface=wroclaw-oracle-tunnel dst-address=192.168.88.2 \
    passthrough=no

/ip firewall mangle add chain=prerouting \
    action=mark-routing new-routing-mark=via-oracle \
    connection-mark=via-oracle passthrough=no
```

## Part 6: Wrocław Firewall

```bash
# Accept :443 inbound from Oracle tunnel
/ip firewall filter add chain=forward action=accept \
    in-interface=wroclaw-oracle-tunnel \
    protocol=tcp dst-address=192.168.88.2 dst-port=443 \
    comment="Accept :443 FROM Oracle"

# Accept :443 replies outbound to Oracle tunnel
/ip firewall filter add chain=forward action=accept \
    out-interface=wroclaw-oracle-tunnel \
    protocol=tcp src-address=192.168.88.2 src-port=443 \
    comment="Accept :443 TO Oracle"

# Drop everything else on the Oracle tunnel
/ip firewall filter add chain=forward action=drop \
    in-interface=wroclaw-oracle-tunnel \
    comment="Drop non-:443 from Oracle"
```

Order the accepts before the defconf `fasttrack` / `accept established,related,untracked`, and place the drop after them.

## Part 7: Testing

```bash
# Oracle
sudo conntrack -L | grep -c "dport=443"
sudo iptables -L FORWARD -nv --line-numbers
sudo wg show wg0

# Wrocław
/ip firewall filter print stats where chain=forward
/interface wireguard peers print detail where name="Oracle-VM"
```

The drop rule counter should stay at 0 during normal traffic.
