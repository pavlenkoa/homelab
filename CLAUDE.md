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

**macmini (default):** ArgoCD, Vault, Authelia, cert-manager, external-secrets, Traefik, n8n

**raspberrypi (tainted):** Transmission (with Gluetun VPN sidecar) - requires toleration to schedule

**Both nodes:** Alloy DaemonSet

**Native macOS:** Emby, Alloy

## Monitoring

Metrics and logs ship to Grafana Cloud.

**macOS (native, outside GitOps):**
- Alloy - host metrics, process metrics (Emby visibility), Emby logs
- Exposes endpoint at `host.internal` for in-cluster Alloy to scrape

**k3s cluster (ArgoCD-managed):**
- Alloy DaemonSet on both nodes
- Collects: node metrics, K8s metrics (cAdvisor, kubelet, kube-state-metrics)
- Scrapes macOS Alloy, remote writes to Grafana Cloud

**Secrets:** Vault path `grafana` contains Grafana Cloud credentials

## TODO

- [ ] Update Alloy chart to latest (replace existing)
- [ ] Deploy Alloy DaemonSet (ArgoCD)
- [ ] Install Alloy on macOS (Homebrew)
- [ ] Configure Grafana Cloud remote write
- [ ] GitHub Action to build images from images/ dir
- [ ] Add Renovate bot for dependency updates

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
│       ├── k3s-cluster.md
│       ├── mikrotik-wireguard.md
│       └── orbstack-networking.md
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
