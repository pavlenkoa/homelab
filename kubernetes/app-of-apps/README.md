# App-of-Apps

GitOps pattern for managing multiple environments with ArgoCD.

## Architecture

```
app-of-apps (Application) ← bootstrap with kubectl apply
└── environments (ApplicationSet) ← git generator discovers values/*.yaml
    └── homelab (Application) ← generated per environment
        ├── homelab (AppProject)
        ├── system (Application) ← in homelab project
        │   ├── system (AppProject)
        │   ├── cilium
        │   ├── ingress-nginx
        │   └── cert-manager
        ├── platform (Application) ← in homelab project
        │   ├── platform (AppProject)
        │   ├── vault
        │   ├── argocd
        │   └── ...
        └── applications (Application) ← in homelab project
            ├── applications (AppProject)
            └── external-services
```

## How It Works

### Consistent Pattern

Both environment and layer levels use the same pattern:
- Create AppProject (wave -10)
- Create child Applications (their respective waves)

| Level | Creates | Children |
|-------|---------|----------|
| `homelab` | homelab AppProject | system, platform, applications |
| `system` | system AppProject | cilium, ingress-nginx, cert-manager |
| `platform` | platform AppProject | vault, argocd, n8n, authelia... |
| `applications` | applications AppProject | external-services |

### Template Files

| File | Renders When | Creates |
|------|--------------|---------|
| `bootstrap.yaml` | kubectl apply | app-of-apps Application |
| `environments.yaml` | renderLayer="" (app-of-apps) | environments ApplicationSet |
| `environment.yaml` | renderLayer="" (homelab) | AppProject + layer Applications |
| `layer.yaml` | renderLayer=X | AppProject + child Applications |
| `_application.tpl` | always | Helper for Application resources |

### renderLayer Parameter

| Value | Template Used | Output |
|-------|---------------|--------|
| (empty at app-of-apps) | environments.yaml | environments ApplicationSet |
| (empty at homelab) | environment.yaml | homelab AppProject + system/platform/applications |
| `system` | layer.yaml | system AppProject + cilium/ingress-nginx/cert-manager |
| `platform` | layer.yaml | platform AppProject + vault/argocd/... |
| `applications` | layer.yaml | applications AppProject + external-services |

## Bootstrap

### Single Environment
```bash
argocd app create homelab \
  --repo https://github.com/pavlenkoa/homelab.git \
  --path kubernetes/app-of-apps \
  --values values/homelab.yaml \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace argocd
```

### Multi-Environment (ApplicationSet)
```bash
argocd app create app-of-apps \
  --repo https://github.com/pavlenkoa/homelab.git \
  --path kubernetes/app-of-apps \
  --file environments-appset.yaml \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace argocd
```
Discovers `values/*.yaml` and generates one Application per environment.

## Adding New Environment

1. Create `values/<env-name>.yaml`:
   ```yaml
   global:
     environmentName: "<env-name>"
   ```

2. Commit and push - ApplicationSet auto-discovers and creates the environment

## Adding New Application

1. Add to `values.yaml` under the appropriate layer:
   ```yaml
   layers:
     platform:
       apps:
         - name: my-app
           enabled: true
           path: kubernetes/charts/my-app
           namespace: my-app
           annotations:
             argocd.argoproj.io/sync-wave: "2"
   ```

2. Create the chart at `kubernetes/charts/my-app/`

3. Create values at `kubernetes/charts/my-app/values/homelab.yaml`

## Projects

| Project | Contains | Filter in UI |
|---------|----------|--------------|
| `default` | app-of-apps | Root application |
| `homelab` | system, platform, applications | Environment layer apps |
| `system` | cilium, ingress-nginx, cert-manager | System components |
| `platform` | vault, argocd, n8n, authelia... | Platform services |
| `applications` | external-services | End-user applications |

## Sync Order

Controlled by sync-waves:
1. AppProject (wave -10) - always created first
2. Layer apps by their configured waves:
   - system: wave -1
   - platform: wave 0
   - applications: wave 1
3. Child apps within layers by their waves
