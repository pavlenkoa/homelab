# Homelab

Personal homelab infrastructure. Kubernetes (k3s) on Mac Mini M4 and Raspberry Pi 4. Traffic routes through Kyiv router via WireGuard to bypass CGNAT.

## Infrastructure

| Location | Hardware | Role |
|----------|----------|------|
| **Wrocław** | Mac Mini M4 | k3s server + worker (OrbStack VM), Emby (native macOS) |
| **Wrocław** | Raspberry Pi 4 | k3s worker, media storage |
| **Kyiv** | MikroTik Router | WireGuard gateway (static IP) |

## Traffic Flow

```
Internet → Cloudflare → Kyiv Router → WireGuard → Wrocław → Services
```

## Project Structure

```
homelab/
├── kubernetes/
│   ├── app-of-apps/         # ArgoCD app-of-apps pattern
│   └── apps/                # Helm wrapper charts + raw manifests for every app
├── images/                  # Custom Docker images
└── docs/
    ├── setup/               # Cluster, router, and networking setup guides
    └── smarthome/           # Smart home design & lighting notes
```

## Setup

See [docs/setup/k3s-cluster.md](docs/setup/k3s-cluster.md) for cluster installation.

See [CLAUDE.md](CLAUDE.md) for detailed project documentation.

---

*Latest iteration done with help of [Claude Code](https://github.com/anthropics/claude-code) :)*
