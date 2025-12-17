# Kubernetes Infrastructure

GitOps-managed Kubernetes infrastructure using ArgoCD with App-of-Apps pattern.

## Directory Structure

```
kubernetes/
├── app-of-apps/                    # ArgoCD App-of-Apps pattern
│   ├── Chart.yaml
│   ├── templates/
│   │   ├── _application.tpl        # Application template helper
│   │   ├── applications.yaml       # Dynamic Application generation
│   │   └── projects.yaml           # ArgoCD Project definitions
│   ├── values.yaml                 # All apps defined here (enabled: true/false)
│   └── values/
│       └── homelab.yaml            # Environment config (just environmentName)
└── charts/                         # All Helm charts (flat structure)
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
    ├── vault-secrets-generator/    # External chart - values only
    │   └── values/
    │       └── homelab.yaml
    └── victoriametrics/
```

## Sync Wave Order

| Wave | Services | Purpose |
|------|----------|---------|
| -3 | argocd | GitOps platform (bootstrap) |
| -2 | ingress-nginx | External traffic routing |
| -1 | vault, external-secrets | Secret management |
| 0 | cert-manager, vault-secrets-generator | TLS certificates, secret generation |
| 1 | All applications | End-user services |

## App-of-Apps Features

**Auto-generated valueFiles:** If `helm.valueFiles` is not specified, path is auto-generated:
- Local charts: `values/<environmentName>.yaml`
- External charts: `kubernetes/charts/<name>/values/<environmentName>.yaml`

**Configuration structure:**
- `values.yaml` - All applications defined with `enabled: true/false`
- `values/homelab.yaml` - Just sets `environmentName: "homelab"`

## Adding New Applications

1. Add chart to `kubernetes/charts/<name>/`
2. Add values file at `kubernetes/charts/<name>/values/homelab.yaml`
3. Add entry to `app-of-apps/values.yaml`:
   ```yaml
   platform:  # or infrastructure/applications
     applications:
       - name: my-app
         enabled: true
         path: kubernetes/charts/my-app
         namespace: my-namespace
         annotations:
           argocd.argoproj.io/sync-wave: "1"
   ```
4. Commit and push - ArgoCD deploys automatically

## Bootstrap

```bash
# Install ArgoCD
kubectl create namespace argocd
helm install argocd kubernetes/charts/argocd \
  -n argocd \
  -f kubernetes/charts/argocd/values/homelab.yaml

# Deploy App-of-Apps
helm install app-of-apps kubernetes/app-of-apps \
  -n argocd \
  -f kubernetes/app-of-apps/values/homelab.yaml
```

## Access ArgoCD

```bash
# Get LoadBalancer IP
kubectl get svc argocd-server -n argocd

# Get admin password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

## Secret Management

Secrets flow: Vault → external-secrets-operator → Kubernetes Secrets

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: myapp-secret
spec:
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: myapp-secret
  data:
    - secretKey: password
      remoteRef:
        key: kv/myapp
        property: password
```

## Traffic Flow

```
Internet → Cloudflare → Kyiv Router → WireGuard → OrbStack LB → ingress-nginx → Services
```

TLS automated via cert-manager + Let's Encrypt + Cloudflare DNS-01.
