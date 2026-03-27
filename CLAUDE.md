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

**Both nodes:** fluent-bit DaemonSet (log collection)

**macmini only:** vmagent Deployment (metrics scraping)

**Native macOS:** Emby, node_exporter, fluent-bit (Emby logs)

## Monitoring

Metrics and logs ship to local VictoriaMetrics and Loki.

**macOS (native, outside GitOps):**
- node_exporter - host metrics, exposed at `host.internal:9100` for in-cluster vmagent to scrape
- fluent-bit - Emby logs, pushes to in-cluster Loki

**k3s cluster (ArgoCD-managed):**
- vmagent Deployment (single replica) - scrapes all metrics (node, kubelet, cAdvisor, kube-state-metrics, macOS, apps)
- fluent-bit DaemonSet on both nodes - collects pod logs, pushes to Loki
- Remote write: VictoriaMetrics (metrics), Loki (logs)

**Secrets:** Vault path `grafana` contains Grafana Cloud credentials

## TODO

- [ ] Install fluent-bit on macOS (Homebrew) for Emby log collection

## Project Structure

```
homelab/
├── CLAUDE.md
├── README.md
├── .github/
│   ├── CODEOWNERS
│   ├── renovate.json5
│   └── workflows/
├── images/
│   ├── gluetun-transmission-cli/
│   ├── transmission-exporter/
│   └── vault-tools/
├── docs/
│   └── setup/
│       ├── k3s-cluster.md
│       ├── mikrotik-wireguard.md
│       └── orbstack-networking.md
└── kubernetes/
    ├── app-of-apps/
    │   ├── Chart.yaml
    │   ├── templates/
    │   └── values.yaml
    └── apps/                   # All applications (Helm wrapper charts + raw manifests)
        ├── fluent-bit/
        ├── vmagent/
        ├── argocd/
        ├── authelia/
        ├── cert-manager/
        ├── cilium/
        ├── cilium-lb/
        ├── external-secrets/
        ├── external-services/  # Local custom
        ├── ingress-nginx/
        ├── n8n/
        ├── transmission/       # Raw manifests (not a chart)
        ├── vault/
        ├── vault-secrets-generator/  # Local custom
        └── victoriametrics/
```

## Helm Charts

All charts use the **wrapper pattern** for Renovate compatibility:
- `Chart.yaml` declares upstream chart as dependency
- `values.yaml` contains sensible defaults
- `values/homelab.yaml` contains environment-specific overrides (hostnames, IPs, secrets)
- Renovate updates chart versions in `Chart.yaml`; ArgoCD fetches dependencies at sync time
- No `Chart.lock` or `.tgz` archives committed to git

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
