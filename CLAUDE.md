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

**Kubernetes (Mac Mini):** ArgoCD, Vault, Authelia, cert-manager, external-secrets, ingress-nginx, n8n

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
└── kubernetes/                      # needs restructure
    ├── app-of-apps/
    ├── infrastructure/
    ├── platform/
    └── applications/
```

## SSH Access

```bash
ssh andrii@macmini.local            # Mac Mini M4
ssh andrii@raspberrypi.local        # Raspberry Pi
ssh andrii@kyiv-router.local        # Kyiv MikroTik
ssh andrii@wroclaw-router.local     # Wrocław MikroTik
```

## Git Conventions

- Stage files explicitly: `git add <file>`
- Commit with `git commit -m 'message'`
- **Never use `git add -A`**
- Never commit `.env` files or secrets

## TODO

### Restructure kubernetes/ directory

Migrate from layered structure (infrastructure/, platform/, applications/) to flat charts/ structure:

```
kubernetes/
├── app-of-apps/
│   ├── Chart.yaml
│   ├── templates/
│   │   ├── _application.tpl
│   │   ├── applications.yaml
│   │   └── projects.yaml
│   └── values/
│       └── homelab.yaml
└── charts/
    ├── argocd/
    │   ├── Chart.yaml
    │   └── values/
    │       └── homelab.yaml
    ├── cert-manager/
    ├── external-secrets/
    ├── external-services/
    ├── ingress-nginx/
    ├── n8n/
    ├── vault/
    ├── vault-secrets-generator/   # External chart - values only, no Chart.yaml
    │   └── values/
    │       └── homelab.yaml
    └── victoriametrics/
```

**Implementation:**
- Update app-of-apps to support flat charts/ structure
- Use `_application.tpl` helper template for DRY Application resources
- External charts (like vault-secrets-generator) have values only, no Chart.yaml
