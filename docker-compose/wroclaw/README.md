# Wrocław Services

Mac Mini M4 location running primary compute services with centralized monitoring and authentication.

## Services Overview

| Service | URL | Purpose | Status |
|---------|-----|---------|--------|
| **Caddy** | `https://*.domain.com` | Reverse proxy with auto-TLS | Active |
| **Authelia** | `https://auth.domain.com` | SSO authentication with 2FA | Active |
| **Immich** | `https://photos.domain.com` | Photo management | Active |
| **Monitoring** | `https://grafana.domain.com` | VictoriaLogs + VictoriaMetrics + Grafana | Active |

## Quick Start

```bash
# Complete setup
cd docker-compose/wroclaw
cp .env.user.example .env.user    # Configure credentials
make all-setup                    # Generate secrets and configs
make all-up                       # Start all services

# Individual service management
make select SERVICE=monitoring    # Select specific service
make setup                        # Setup selected service
make up                           # Start selected service
make logs                         # View logs
```

## Service Details

### Authelia (Authentication)
- **Purpose**: Centralized SSO with 2FA for all protected services
- **Features**: WebAuthn/Passkeys, TOTP, Redis sessions
- **Quick Setup**: `make setup DOMAIN=your-domain.com`
- **Protected Services**: Transmission, Alertmanager, Test endpoints
- **Default Login**: admin / (24-character generated password)

### Caddy (Reverse Proxy)
- **Purpose**: Web gateway with automatic TLS via Cloudflare DNS
- **Features**: Location-aware config, Authelia integration, static file serving
- **Requirements**: Cloudflare API token with DNS permissions
- **Configuration**: Template-based with auto-regeneration
- **Endpoints**: All `*.domain.com` services

### Immich (Photo Management)
- **Purpose**: Self-hosted photo management with ML features
- **Features**: Face detection, search, mobile sync, OAuth with Authelia
- **Storage**: Local SSD + NFS mount to Kyiv for external libraries
- **Database**: PostgreSQL with Redis for job queues
- **Access**: Internal authentication + OAuth integration

### Monitoring Stack
- **Components**: VictoriaLogs + VictoriaMetrics + Grafana + Alloy
- **Role**: Central monitoring hub collecting from all locations
- **Data Sources**: 
  - Metrics: Local + Kyiv → VictoriaMetrics
  - Logs: Local + Kyiv → VictoriaLogs
- **Dashboards**: Infrastructure, services, network topology
- **Exporters**: node_exporter, cAdvisor, MikroTik, blackbox

## Network Architecture

### Connections
- **Local Services**: Direct container/host access
- **Kyiv Services**: Via WireGuard tunnel (192.168.1.x)
- **External Access**: Cloudflare → Kyiv static IP → WireGuard → Wrocław

### Storage
- **Local**: 2TB SSD for containers, databases, monitoring data
- **Remote**: NFS mount from Kyiv (8TB) for Emby media access

## Common Commands

```bash
# Service-specific operations
make select SERVICE=authelia
make setup                        # Setup with domain prompt
make up                          # Start with config validation
make logs                        # View service logs
make restart                     # Restart with template regeneration

# Monitoring operations
make monitoring-status           # Check monitoring stack health
make monitoring-generate-secrets # Regenerate monitoring credentials

# Authelia operations  
make authelia-get-code          # Get 2FA verification code
make authelia-generate-new-password # Reset admin password
```

## Troubleshooting

### Service Access Issues
1. Check Caddy is running: `make select SERVICE=caddy && make status`
2. Verify domain DNS points to Kyiv public IP
3. Check Authelia for protected services: `make authelia-get-code`

### Configuration Issues
1. Templates auto-regenerate on `make up`/`make restart`
2. Check `.env.user` for required variables
3. Force regeneration: `make setup`

### Monitoring Issues
1. Check VictoriaMetrics storage: `make monitoring-status`
2. Verify Kyiv metrics forwarding via Grafana dashboards
3. Check Alloy configuration: `make logs SERVICE=monitoring`

## Security Notes

- All secrets auto-generated during setup
- Authelia provides 2FA for protected endpoints
- Caddy manages TLS certificates automatically
- No direct port exposure (traffic via Kyiv tunnel)
- Service isolation via Docker networks