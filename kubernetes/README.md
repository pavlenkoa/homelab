# Kubernetes Infrastructure

GitOps-managed Kubernetes infrastructure using ArgoCD with App-of-Apps pattern.

## Directory Structure

```
kubernetes/
├── app-of-apps/                    # ArgoCD App-of-Apps pattern
│   ├── Chart.yaml
│   ├── templates/
│   │   ├── _helpers.tpl            # Shared template helpers
│   │   ├── _application.tpl        # Application resource template
│   │   ├── layers.yaml             # Layer Applications + environment AppProject
│   │   └── children.yaml           # Child Applications + layer AppProject
│   ├── bootstrap/
│   │   └── environments-appset.yaml  # Multi-environment auto-discovery
│   ├── values.yaml                 # All apps defined here (enabled: true/false)
│   └── values/
│       └── homelab.yaml            # Environment config (just environment name)
└── apps/                           # All applications (Helm wrapper charts + raw manifests)
    ├── argocd/
    ├── authelia/
    ├── cert-manager/
    ├── cilium/
    ├── cilium-lb/
    ├── external-secrets/
    ├── external-services/
    ├── ingress-nginx/
    ├── n8n/
    ├── transmission/               # Raw manifests (not a chart)
    ├── vault/
    ├── vault-secrets-generator/    # External chart - values only
    └── victoriametrics/
```

## Architecture

The app-of-apps uses a hierarchical rendering approach via `renderLayer` parameter:

```
environments (ApplicationSet)
  └─ homelab Application (renderLayer="")
      ├─ homelab AppProject
      ├─ system Application (renderLayer=system)
      │   ├─ system AppProject
      │   ├─ cilium
      │   ├─ ingress-nginx
      │   └─ cert-manager
      ├─ platform Application (renderLayer=platform)
      │   ├─ platform AppProject
      │   ├─ vault
      │   ├─ external-secrets
      │   ├─ argocd
      │   ├─ n8n
      │   └─ authelia
      └─ applications Application (renderLayer=applications)
          ├─ applications AppProject
          └─ external-services
```

## Layers

| Layer | Wave | Description |
|-------|------|-------------|
| system | -1 | Core cluster components (CNI, ingress, certificates) |
| platform | 0 | Platform services and DevOps tools |
| applications | 1 | End-user applications and services |

## Sync Wave Order

| Wave | Services | Purpose |
|------|----------|---------|
| -10 | AppProjects | Project definitions |
| -3 | cilium | CNI networking |
| -2 | ingress-nginx | External traffic routing |
| 0 | cert-manager, vault, external-secrets | TLS certificates, secret management |
| 1 | argocd | GitOps platform |
| 2 | vault-secrets-generator, victoriametrics | Secret generation, monitoring |
| 3 | n8n, authelia | Platform services |
| 4 | external-services | End-user services |

## Adding New Applications

1. Add chart to `kubernetes/apps/<name>/`
2. Add values file at `kubernetes/apps/<name>/values/homelab.yaml`
3. Add entry to appropriate layer in `app-of-apps/values.yaml`:
   ```yaml
   layers:
     platform:  # or system/applications
       children:
         - name: my-app
           enabled: true
           namespace: my-namespace
           annotations:
             argocd.argoproj.io/sync-wave: "2"
   ```
4. Commit and push - ArgoCD deploys automatically

### External Repository Applications

For apps from external repositories (e.g., vault-secrets-generator):

```yaml
- name: vault-secrets-generator
  enabled: true
  namespace: vsg
  path: helm/vault-secrets-generator
  repository:
    url: "https://github.com/pavlenkoa/vault-secrets-generator.git"
    targetRevision: "HEAD"
```

Values are still pulled from homelab repo at `kubernetes/apps/<name>/values/<env>.yaml`.

## Bootstrap

### Option 1: ApplicationSet (Recommended)

```bash
# Install ArgoCD first
kubectl create namespace argocd
helm install argocd kubernetes/apps/argocd \
  -n argocd \
  -f kubernetes/apps/argocd/values/homelab.yaml

# Deploy bootstrap ApplicationSet
argocd app create app-of-apps \
  --repo https://github.com/pavlenkoa/homelab.git \
  --path kubernetes/app-of-apps/bootstrap \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace argocd \
  --sync-policy automated --self-heal --auto-prune
```

The ApplicationSet auto-discovers `values/*.yaml` files and creates an Application per environment.

### Option 2: Direct Helm Install

```bash
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

## Configuration Merge Rules

| Element | Behavior | Priority |
|---------|----------|----------|
| syncPolicy | Override | Later wins |
| syncOptions | Additive | All merged |
| ignoreDifferences | Override | First non-empty |
| additionalIgnoreDifferences | Additive | All merged |
| annotations | Merge | Later wins |
| finalizers | Override | First non-empty |

**Hierarchy:** childDefaults → layerChildDefaults → child-specific config

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
