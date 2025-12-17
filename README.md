# Homelab

Personal homelab infrastructure. Kubernetes on Mac Mini M4, Docker Compose on Raspberry Pi. Traffic routes through Kyiv router via WireGuard to bypass CGNAT.

## Infrastructure

| Location | Hardware | Role |
|----------|----------|------|
| **Wrocław** | Mac Mini M4 + Raspberry Pi 4 | All compute (Kubernetes, Docker, native apps) |
| **Kyiv** | MikroTik Router | WireGuard gateway (static IP) |

## Traffic Flow

```
Internet → Cloudflare → Kyiv Router → WireGuard → Wrocław → Services
```

## Project Structure

```
homelab/
├── docker-compose/          # Raspberry Pi services
│   └── transmission/
├── kubernetes/              # Mac Mini K8s (ArgoCD, Vault, Authelia, etc.)
├── images/                  # Custom Docker images
└── docs/setup/              # Router setup guides
```

## Quick Start

**Transmission (Raspberry Pi):**
```bash
cd docker-compose/transmission
cp .env.example .env         # Configure VPN credentials
docker compose up -d
```

See [CLAUDE.md](CLAUDE.md) for detailed documentation.
