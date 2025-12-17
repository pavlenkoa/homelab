# Homelab Infrastructure

Personal homelab with Kubernetes (OrbStack) on Mac Mini M4 and Docker Compose on Raspberry Pi. External traffic routes through Kyiv router via WireGuard to bypass CGNAT.

## Infrastructure

**Wrocław (all compute):**
- Mac Mini M4 - Kubernetes (OrbStack), Emby (native)
- Raspberry Pi 4 - Docker Compose (Transmission)

**Kyiv:**
- MikroTik Router - WireGuard gateway to static IP

**Traffic:** Internet → Cloudflare → Kyiv Router → WireGuard (10.77.88.0/30) → Wrocław

## What Runs Where

**Kubernetes (Mac Mini):** ArgoCD, Vault, Authelia, cert-manager, external-secrets, ingress-nginx, n8n, victoriametrics

**Docker Compose (Raspberry Pi):** Transmission

**Native (Mac Mini):** Emby

## Project Structure

```
homelab/
├── CLAUDE.md
├── README.md
├── docker-compose/
│   └── transmission/
│       ├── docker-compose.yaml
│       └── .env.example
├── images/
│   ├── transmission/
│   ├── transmission-exporter/
│   └── vault-tools/
├── docs/
│   └── setup/
│       └── mikrotik-wireguard.md
└── kubernetes/
    ├── app-of-apps/
    │   ├── Chart.yaml
    │   ├── templates/
    │   │   ├── _application.tpl
    │   │   ├── applications.yaml
    │   │   └── projects.yaml
    │   ├── values.yaml             # All apps defined (enabled: true/false)
    │   └── values/
    │       └── homelab.yaml        # Just environmentName
    └── charts/                     # Flat structure
        ├── argocd/
        │   ├── Chart.yaml
        │   └── values/
        │       └── homelab.yaml
        ├── authelia/
        ├── cert-manager/
        ├── external-secrets/
        ├── external-services/
        ├── ingress-nginx/
        ├── n8n/
        ├── vault/
        ├── vault-secrets-generator/  # External chart - values only
        │   └── values/
        │       └── homelab.yaml
        └── victoriametrics/
```

## SSH Access

```bash
ssh andrii@macmini.local            # Mac Mini M4
ssh andrii@raspberrypi.local        # Raspberry Pi
ssh andrii@kyiv-router.local        # Kyiv MikroTik
ssh andrii@wroclaw-router.local     # Wrocław MikroTik
```

## Git Conventions

- Stage files explicitly with `git add <file>`
- Commit with `git commit -m 'message'`
- Can use `git commit -am 'message'` for tracked files
- **Never use `git add -A`** - always stage files explicitly
