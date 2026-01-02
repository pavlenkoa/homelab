# Homelab Infrastructure

Single Kubernetes cluster (k3s + Cilium) spanning Mac Mini M4 and Raspberry Pi 4. External traffic routes through Kyiv router via WireGuard to bypass CGNAT.

## Infrastructure

**Wrocław (compute):**
- Mac Mini M4 - k3s control plane (OrbStack VM), Emby (native macOS)
- Raspberry Pi 4 - k3s worker node (8TB disk for media)

**Kyiv:**
- MikroTik Router - WireGuard gateway to static IP

**Traffic:** Internet → Cloudflare → Kyiv Router → WireGuard (10.77.88.0/30) → Wrocław

## What Runs Where

**macmini (default):** ArgoCD, Vault, Authelia, cert-manager, external-secrets, Traefik, n8n, victoriametrics

**raspberrypi (tainted):** Transmission (with Gluetun VPN sidecar) - requires toleration to schedule

**Native macOS:** Emby

## TODO

- [ ] Unify infrastructure and platform projects in app-of-apps
- [ ] Deploy app-of-apps (ArgoCD, Vault, etc.)
- [ ] Restore Vault data
- [ ] Add Transmission to app-of-apps with RPi toleration

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

## OrbStack k3s VM shell

```bash
orb -m macmini
```

## Git Conventions

- Stage files explicitly with `git add <file>`
- Commit with `git commit -m 'message'`
- Can use `git commit -am 'message'` for tracked files
- **Never use `git add -A`** - always stage files explicitly
