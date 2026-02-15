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
│   │   ├── parents.yaml            # Parent Applications + parents AppProject
│   │   └── children.yaml           # Child Applications + parent AppProject
│   └── values.yaml                 # All apps defined here (enabled: true/false)
└── apps/                           # All applications (Helm wrapper charts + raw manifests)
    ├── alloy/
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

The app-of-apps uses a hierarchical rendering approach via `renderParent` parameter:

```
app-of-apps (Application) ← bootstrap with argocd CLI
├── parents (AppProject)
├── system (Application, renderParent=system)
│   ├── system (AppProject)
│   ├── cilium
│   ├── ingress-nginx
│   └── cert-manager
├── platform (Application, renderParent=platform)
│   ├── platform (AppProject)
│   ├── vault
│   ├── external-secrets
│   ├── argocd
│   ├── alloy
│   ├── n8n
│   └── authelia
└── applications (Application, renderParent=applications)
    ├── applications (AppProject)
    ├── external-services
    └── transmission
```

## Parents

| Parent | Wave | Description |
|--------|------|-------------|
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
| 2 | alloy, vault-secrets-generator, victoriametrics | Monitoring, secret generation |
| 3 | n8n, authelia | Platform services |
| 4 | external-services, transmission | End-user services |

## Adding New Applications

1. Add chart to `kubernetes/apps/<name>/`
2. Add values file at `kubernetes/apps/<name>/values/homelab.yaml`
3. Add entry to appropriate parent in `app-of-apps/values.yaml`:
   ```yaml
   parents:
     platform:  # or system/applications
       children:
         - name: my-app
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

```bash
# Install ArgoCD first
kubectl create namespace argocd
helm install argocd kubernetes/apps/argocd \
  -n argocd

# Deploy app-of-apps
argocd app create app-of-apps \
  --repo https://github.com/pavlenkoa/homelab.git \
  --path kubernetes/app-of-apps \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace argocd \
  --sync-policy automated --auto-prune
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

**Hierarchy:** childDefaults → parent-level childDefaults → child-specific config

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
