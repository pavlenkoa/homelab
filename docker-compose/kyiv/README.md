# Kyiv Services

Raspberry Pi 4 location serving as internet gateway and storage server with VPN-protected BitTorrent.

## Services Overview

| Service | Purpose | Status | Access |
|---------|---------|--------|--------|
| **Transmission** | BitTorrent with ProtonVPN protection | Active | `https://transmission.domain.com` |
| **Monitoring** | Metrics/logs collection agent | Active | Alloy UI: `http://localhost:12345` |

## Quick Start

```bash
# Complete setup
cd docker-compose/kyiv
cp .env.user.example .env.user    # Configure VPN credentials
make all-setup                    # Generate configs
make all-up                       # Start all services

# Individual service management
make select SERVICE=transmission  # Select specific service
make setup                        # Setup selected service
make up                           # Start selected service
make logs                         # View logs
```

## Service Details

### Transmission (BitTorrent + VPN)
- **Purpose**: Secure BitTorrent client with ProtonVPN protection
- **VPN**: WireGuard connection via Gluetun container
- **Features**: 
  - Kill switch prevents non-VPN traffic
  - Automatic port forwarding for better connectivity
  - Organized downloads (TV, movies, animations)
  - Auto-add support via watch folder
- **Requirements**: ProtonVPN WireGuard private key
- **Downloads**: Saved directly to `/media/emby/` folders for Emby access

#### Download Organization
| Category | Path | Purpose |
|----------|------|---------|
| TV Shows | `/media/emby/tv` | Television series |
| Movies | `/media/emby/movies` | Films |
| TV Animation | `/media/emby/tvanimation` | Animated TV series |
| Animation | `/media/emby/animation` | Animated films |

### Monitoring (Collection Agent)
- **Purpose**: Unified metrics and logs collection for homelab
- **Components**: Grafana Alloy with multiple exporters
- **Data Flow**:
  - Metrics → Oracle Cloud VictoriaMetrics
  - Logs → Wrocław VictoriaLogs
- **Exporters**:
  - `node_exporter` - System metrics
  - `cAdvisor` - Container metrics  
  - `mikrotik_exporter` - Router metrics (2 devices)
  - `transmission_exporter` - BitTorrent metrics
  - `blackbox_exporter` - External service monitoring

## Network Architecture

### Role as Internet Gateway
- **Static IP**: Provides public access point for CGNAT bypass
- **WireGuard Server**: Connects Wrocław services to internet
- **Traffic Flow**: `Internet → Kyiv → WireGuard Tunnel → Wrocław`
- **Port Forwarding**: Routes HTTPS traffic to Wrocław services

### Storage Server
- **Capacity**: 8TB RAID array
- **NFS Export**: `/mnt/media` shared with Wrocław for Emby
- **Usage**: 
  - Direct access for Transmission downloads
  - Remote access for Emby media streaming
  - Backup storage for critical data

## Common Commands

```bash
# Transmission operations
make select SERVICE=transmission
make up                          # Start with VPN connection
make logs                        # View combined logs
make test-vpn                    # Verify VPN connection
make logs-gluetun               # VPN-specific logs
make logs-transmission          # BitTorrent-specific logs

# Monitoring operations  
make select SERVICE=monitoring
make setup LOCATION=kyiv        # Location-aware setup
make status                     # Check collection agents
make logs                       # View Alloy logs

# System operations
make all-status                 # Check all services
make all-logs                   # View all service logs
```

## ProtonVPN Setup

### Getting WireGuard Configuration
1. Login to ProtonVPN account
2. Navigate to Downloads → WireGuard configuration
3. Generate new configuration for a server location
4. Copy the `PrivateKey` value
5. Add to `.env.user`:
   ```bash
   WIREGUARD_PRIVATE_KEY=your_actual_private_key_here
   ```

### VPN Features
- **Kill Switch**: Blocks all traffic if VPN disconnects
- **Port Forwarding**: Automatically configured every 45 seconds
- **DNS**: Uses ProtonVPN DNS servers
- **Protocol**: WireGuard for optimal performance

## Storage Management

### NFS Exports
- **Export**: `/mnt/media` → Wrocław Mac Mini
- **Access**: Secure via WireGuard tunnel only
- **Performance**: Optimized for media streaming

### Download Management
- **Auto-organization**: Files sorted by type automatically
- **Watch folder**: `/media/transmission/watch` for .torrent files
- **Completed**: Files moved to appropriate Emby folders

## Troubleshooting

### Transmission Issues
```bash
# Check VPN connection
make select SERVICE=transmission
make test-vpn

# View detailed logs
make logs-gluetun               # VPN connection issues
make logs-transmission          # BitTorrent issues

# Restart with fresh VPN connection
make restart
```

### Monitoring Issues
```bash
# Check collection agent status
make select SERVICE=monitoring
make status

# Verify remote connections
make logs | grep "remote_write"  # Metrics forwarding
make logs | grep "loki"          # Log forwarding
```

### Network Issues
```bash
# Check WireGuard tunnel
sudo wg show

# Test connectivity to Wrocław
ping 192.168.88.2

# Check NFS mount
showmount -e localhost
```

## Security Notes

- **VPN Protection**: All BitTorrent traffic encrypted via ProtonVPN
- **Tunnel Encryption**: WireGuard protects inter-site communication  
- **No Direct Exposure**: Only public ports are 22 (SSH) and 443 (HTTPS)
- **Firewall**: iptables rules prevent VPN traffic leaks
- **NFS Security**: Exports restricted to WireGuard network only