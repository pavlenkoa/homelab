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

**macmini (default):** ArgoCD, Vault, Authelia, cert-manager, external-secrets, Grafana, Loki, VictoriaMetrics, Home Assistant, Zigbee2MQTT, Mosquitto, Tailscale operator, Hubble UI

**raspberrypi (tainted):** Transmission (with Gluetun VPN sidecar) — requires toleration to schedule

**Both nodes (DaemonSets):** fluent-bit (logs), node-exporter, kgateway Envoy proxy (hostNetwork)

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

## Project Structure

```
homelab/
├── CLAUDE.md
├── README.md
├── .github/
│   ├── CODEOWNERS
│   ├── renovate.json5
│   └── workflows/
├── images/                    # Custom Docker images
│   ├── claude-code/
│   ├── gamja/
│   ├── gluetun-transmission-cli/
│   ├── soju/
│   ├── transmission-exporter/
│   └── vault-tools/
├── docs/
│   ├── setup/                 # k3s, MikroTik WireGuard, OrbStack networking
│   └── smarthome/             # Smart home design & lighting notes
└── kubernetes/
    ├── app-of-apps/           # ArgoCD app-of-apps (parents: system, platform, monitoring, applications, smarthome)
    └── apps/                  # All applications (Helm wrapper charts + raw manifests)
        ├── system/            # cilium, kgateway, cert-manager, hubble-ui
        ├── platform/          # vault, external-secrets, argocd, authelia, tailscale, vault-secrets-generator
        ├── monitoring/        # victoriametrics, vmagent, loki, grafana, fluent-bit,
        │                      # kube-state-metrics, node-exporter, blackbox-exporter, mikrotik-exporter
        ├── applications/      # external-services, transmission, claude-code, soju, gamja
        └── smarthome/         # mosquitto, zigbee2mqtt, home-assistant
```

Note: the subdirectory grouping above is conceptual — all app folders live directly under `kubernetes/apps/`. Parent assignment lives in `app-of-apps/values.yaml`.

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
