# Homelab

Distributed homelab infrastructure across two locations, overcoming CGNAT limitations with WireGuard tunnels.

## 🏗️ Architecture

| Location | Hardware | Network | Role |
|----------|----------|---------|------|
| **Wrocław** | Mac Mini M4 (2TB) | 192.168.88.0/24 (CGNAT) | Primary compute, media services |
| **Kyiv** | Raspberry Pi 4 (8TB) | 192.168.1.0/24 (Static IP) | Internet gateway, NFS storage |

## 🚀 Services

| Service | Location | URL | Purpose |
|---------|----------|-----|---------|
| **Caddy** | Wrocław | https://*.domain.com | Reverse proxy with TLS |
| **Authelia** | Wrocław | https://auth.domain.com | Centralized authentication |
| **Emby** | Wrocław | https://emby.domain.com | Media server (uses Kyiv NFS) |
| **Immich** | Wrocław | https://photos.domain.com | Photo management |
| **Transmission** | Kyiv | https://transmission.domain.com | BitTorrent with VPN |
| **Monitoring** | Wrocław | https://grafana.domain.com | VictoriaLogs + VictoriaMetrics + Grafana |

## 🚦 Quick Start

```bash
# First-time setup (location-specific)
cd docker-compose/wroclaw
cp .env.user.example .env.user    # Configure credentials
make all-setup                    # Generate secrets and configs
make all-up                       # Start all services
make all-logs                     # View logs

# Individual service management
cd docker-compose/wroclaw
make select SERVICE=monitoring    # Select specific service
make setup                        # Setup selected service
make up                           # Start selected service
make logs                         # View logs

# Service-specific commands
make monitoring-status             # Check monitoring status
make authelia-get-code            # Get Authelia verification code
make monitoring-generate-secrets  # Regenerate monitoring secrets
```

## 📁 Project Structure

```
homelab/
├── docker-compose/           # Service orchestration
│   ├── _base/               # Base service definitions
│   ├── wroclaw/             # Mac Mini services (primary compute)
│   │   ├── authelia.yaml    # Authentication + Redis
│   │   ├── caddy.yaml       # Reverse proxy with TLS
│   │   ├── immich.yaml      # Photo management
│   │   └── monitoring.yaml  # VictoriaLogs + VictoriaMetrics + Grafana
│   └── kyiv/                # Raspberry Pi services (gateway)
│       ├── monitoring.yaml  # Metrics collection agents
│       └── transmission.yaml # BitTorrent with VPN
├── docs/                    # Documentation
│   ├── services/            # Service-specific docs
│   └── ARCHITECTURE.md      # Technical architecture
├── scripts/                 # Deployment automation
│   ├── deploy               # Main deployment CLI
│   └── Makefile             # Make command wrapper
└── images/                  # Custom Docker images
```

## 🔧 Development Workflow

- **Templates**: Configs use `.tmpl` files with `{{VARIABLE}}` placeholders
- **Secrets**: Auto-generated in `.env.generated`, user config in `.env.user`
- **Automation**: Use `make` commands for all operations
- **Location-aware**: Run from `docker-compose/wroclaw/` or `docker-compose/kyiv/`
- **Service selection**: `make select SERVICE=<name>` then use short commands
- **Change flow**: Edit template → `make restart` → Auto-regenerates and restarts

## 📚 Documentation

- **Service docs**: `docs/services/<service>.md` - Individual service documentation
- **Architecture**: `docs/ARCHITECTURE.md` - Network topology and design decisions
- **Setup guides**: `docs/setup/` - Hardware and router configuration guides
