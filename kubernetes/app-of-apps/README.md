# App-of-Apps

GitOps pattern for managing ArgoCD applications with a parent/child hierarchy.

## Architecture

```
app-of-apps (Application) ← bootstrap with argocd CLI
├── parents (AppProject)
├── system (Application) ← in parents project
│   ├── system (AppProject)
│   ├── cilium, kgateway, cert-manager, hubble-ui
├── platform (Application) ← in parents project
│   ├── platform (AppProject)
│   ├── vault, external-secrets, argocd,
│   │   vault-secrets-generator, tailscale, authelia
├── monitoring (Application) ← in parents project
│   ├── monitoring (AppProject)
│   ├── victoriametrics, vmagent, loki, grafana,
│   │   fluent-bit, kube-state-metrics, node-exporter,
│   │   blackbox-exporter, mikrotik-exporter
├── applications (Application) ← in parents project
│   ├── applications (AppProject)
│   ├── external-services, transmission, claude-code, soju, gamja
└── smarthome (Application) ← in parents project
    ├── smarthome (AppProject)
    └── mosquitto, zigbee2mqtt, home-assistant
```

## How It Works

### Consistent Pattern

Both environment and parent levels use the same pattern:
- Create AppProject (wave -10)
- Create child Applications (their respective waves)

| Level | Creates | Children |
|-------|---------|----------|
| `app-of-apps` | parents AppProject | system, platform, monitoring, applications, smarthome |
| `system` | system AppProject | cilium, kgateway, cert-manager, hubble-ui |
| `platform` | platform AppProject | vault, external-secrets, argocd, vault-secrets-generator, tailscale, authelia |
| `monitoring` | monitoring AppProject | victoriametrics, vmagent, loki, grafana, fluent-bit, exporters |
| `applications` | applications AppProject | external-services, transmission, claude-code, soju, gamja |
| `smarthome` | smarthome AppProject | mosquitto, zigbee2mqtt, home-assistant |

### Template Files

| File | Renders When | Creates |
|------|--------------|---------|
| `parents.yaml` | renderParent="" | AppProject + parent Applications |
| `children.yaml` | renderParent=X | AppProject + child Applications |
| `_application.tpl` | always | Helper for Application resources |
| `_helpers.tpl` | always | Shared helpers (syncPolicy, labels, etc.) |

### renderParent Parameter

| Value | Template Used | Output |
|-------|---------------|--------|
| (empty) | parents.yaml | parents AppProject + the five parent Applications |
| `system` | children.yaml | system AppProject + its children |
| `platform` | children.yaml | platform AppProject + its children |
| `monitoring` | children.yaml | monitoring AppProject + its children |
| `applications` | children.yaml | applications AppProject + its children |
| `smarthome` | children.yaml | smarthome AppProject + its children |

## Bootstrap

```bash
argocd app create app-of-apps \
  --repo https://github.com/pavlenkoa/homelab.git \
  --path kubernetes/app-of-apps \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace argocd \
  --sync-policy automated --auto-prune
```

## Adding New Application

1. Add to `values.yaml` under the appropriate parent:
   ```yaml
   parents:
     platform:
       children:
         - name: my-app
           namespace: my-app
           annotations:
             argocd.argoproj.io/sync-wave: "2"
   ```

2. Create the chart at `kubernetes/apps/my-app/`

3. Create values at `kubernetes/apps/my-app/values/homelab.yaml`

## Features

### Labels

Parent Applications get `environment: <envName>` label automatically. Child Applications get `parent: <parentName>` label. Custom labels can be added via `parentDefaults.labels`, `childDefaults.labels`, or per-app `labels`.

### excludeChildren

Exclude specific children from a parent without removing them from values:
```yaml
parents:
  platform:
    excludeChildren:
      - victoriametrics
      - grafana
```

### extraChildren

Add extra children to a parent (e.g., from environment overrides):
```yaml
parents:
  platform:
    extraChildren:
      - name: extra-app
        namespace: extra
```

## Projects

| Project | Contains | Filter in UI |
|---------|----------|--------------|
| `default` | app-of-apps | Root application |
| `parents` | system, platform, monitoring, applications, smarthome | Parent apps |
| `system` | cilium, kgateway, cert-manager, hubble-ui | System components |
| `platform` | vault, external-secrets, argocd, vault-secrets-generator, tailscale, authelia | Platform services |
| `monitoring` | victoriametrics, vmagent, loki, grafana, fluent-bit, exporters | Observability stack |
| `applications` | external-services, transmission, claude-code, soju, gamja | End-user applications |
| `smarthome` | mosquitto, zigbee2mqtt, home-assistant | Smart home stack |

## Sync Order

Controlled by sync-waves:
1. AppProject (wave -10) - always created first
2. Parent apps by their configured waves:
   - system: wave -1
   - platform: wave 0
   - monitoring: wave 1
   - applications: wave 1
   - smarthome: wave 2
3. Child apps within parents by their waves
