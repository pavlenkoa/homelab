# Homelab Infrastructure

Personal homelab with Kubernetes on Mac Mini M4 (OrbStack) and Raspberry Pi 4 (k3s). External traffic routes through Kyiv router via WireGuard to bypass CGNAT.

## Infrastructure

**Wrocław (all compute):**
- Mac Mini M4 - Kubernetes (OrbStack), Emby (native)
- Raspberry Pi 4 - Kubernetes (k3s)

**Kyiv:**
- MikroTik Router - WireGuard gateway to static IP

**Traffic:** Internet → Cloudflare → Kyiv Router → WireGuard (10.77.88.0/30) → Wrocław

## What Runs Where

**Kubernetes (Mac Mini):** ArgoCD, Vault, Authelia, cert-manager, external-secrets, ingress-nginx, n8n, victoriametrics

**Kubernetes (Raspberry Pi):** Transmission (with Gluetun VPN sidecar)

**Native (Mac Mini):** Emby

## Raspberry Pi k3s Plan

k3s installed with `--disable traefik --disable servicelb`. Transmission manually deployed for testing.

**TODO:**
- Rename `values/homelab.yaml` to `values/macmini.yaml`
- Add RPi as second cluster in ArgoCD (`values/raspberrypi.yaml`)
- Install Traefik on RPi
- Configure Vault AppRole for RPi (separate cluster can't use k8s auth)
- Install ESO on RPi (AppRole auth, Secret ID created manually)
- Migrate Transmission to ArgoCD-managed deployment

**Notes:**
- Custom image `kubernia/gluetun-transmission-cli:latest` requires `imagePullPolicy: Never` (local image)
- Config: `/home/andrii/transmission-config` (hostPath)
- Media: `/media/emby/*` (hostPath)

## Project Structure

```
homelab/
├── CLAUDE.md
├── README.md
├── docker-compose/
│   └── transmission/           # Legacy - migrated to k8s
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
    ├── manifests/              # Raw manifests for RPi k3s
    │   └── transmission/
    │       ├── namespace.yaml
    │       ├── secret.yaml
    │       ├── statefulset.yaml
    │       └── service.yaml
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
        ├── authelia/
        ├── cert-manager/
        ├── external-secrets/
        ├── external-services/
        ├── ingress-nginx/
        ├── n8n/
        ├── vault/
        ├── vault-secrets-generator/
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
