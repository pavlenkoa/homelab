# App-of-Apps

GitOps pattern for managing ArgoCD applications with a parent/child hierarchy.

## Architecture

```
app-of-apps (Application) ← bootstrap with argocd CLI
├── parents (AppProject)
├── system (Application) ← in parents project
│   ├── system (AppProject)
│   ├── cilium
│   ├── ingress-nginx
│   └── cert-manager
├── platform (Application) ← in parents project
│   ├── platform (AppProject)
│   ├── vault
│   ├── argocd
│   └── ...
└── applications (Application) ← in parents project
    ├── applications (AppProject)
    └── external-services
```

## How It Works

### Consistent Pattern

Both environment and parent levels use the same pattern:
- Create AppProject (wave -10)
- Create child Applications (their respective waves)

| Level | Creates | Children |
|-------|---------|----------|
| `app-of-apps` | parents AppProject | system, platform, applications |
| `system` | system AppProject | cilium, ingress-nginx, cert-manager |
| `platform` | platform AppProject | vault, argocd, n8n, authelia... |
| `applications` | applications AppProject | external-services, transmission |

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
| (empty) | parents.yaml | parents AppProject + system/platform/applications |
| `system` | children.yaml | system AppProject + cilium/ingress-nginx/cert-manager |
| `platform` | children.yaml | platform AppProject + vault/argocd/... |
| `applications` | children.yaml | applications AppProject + external-services/transmission |

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
| `parents` | system, platform, applications | Parent apps |
| `system` | cilium, ingress-nginx, cert-manager | System components |
| `platform` | vault, argocd, n8n, authelia... | Platform services |
| `applications` | external-services, transmission | End-user applications |

## Sync Order

Controlled by sync-waves:
1. AppProject (wave -10) - always created first
2. Parent apps by their configured waves:
   - system: wave -1
   - platform: wave 0
   - applications: wave 1
3. Child apps within parents by their waves
