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
    ├── argocd/
    ├── authelia/
    ├── blackbox-exporter/
    ├── cert-manager/
    ├── cilium/
    ├── claude-code/                # Raw manifests
    ├── external-secrets/
    ├── external-services/          # Local custom chart
    ├── fluent-bit/
    ├── gamja/                      # Raw manifests (IRC web client)
    ├── grafana/
    ├── home-assistant/
    ├── hubble-ui/                  # Raw manifests
    ├── kgateway/
    ├── kube-state-metrics/
    ├── loki/
    ├── mikrotik-exporter/          # Raw manifests
    ├── mosquitto/                  # Raw manifests
    ├── node-exporter/
    ├── soju/                       # Raw manifests (IRC bouncer)
    ├── tailscale/
    ├── transmission/               # Raw manifests (not a chart)
    ├── vault/
    ├── vault-secrets-generator/    # External chart - values only
    ├── victoriametrics/
    ├── vmagent/
    └── zigbee2mqtt/
```

## Architecture

The app-of-apps uses a hierarchical rendering approach via `renderParent` parameter:

```
app-of-apps (Application) ← bootstrap with argocd CLI
├── parents (AppProject)
├── system (Application, renderParent=system)
│   ├── system (AppProject)
│   ├── cilium
│   ├── kgateway
│   ├── cert-manager
│   └── hubble-ui
├── platform (Application, renderParent=platform)
│   ├── platform (AppProject)
│   ├── vault
│   ├── external-secrets
│   ├── argocd
│   ├── vault-secrets-generator
│   ├── tailscale
│   └── authelia
├── monitoring (Application, renderParent=monitoring)
│   ├── monitoring (AppProject)
│   ├── victoriametrics
│   ├── vmagent
│   ├── loki
│   ├── grafana
│   ├── fluent-bit
│   ├── kube-state-metrics
│   ├── node-exporter
│   ├── blackbox-exporter
│   └── mikrotik-exporter
├── applications (Application, renderParent=applications)
│   ├── applications (AppProject)
│   ├── external-services
│   ├── transmission
│   ├── claude-code
│   ├── soju
│   └── gamja
└── smarthome (Application, renderParent=smarthome)
    ├── smarthome (AppProject)
    ├── mosquitto
    ├── zigbee2mqtt
    └── home-assistant
```

## Parents

| Parent | Wave | Description |
|--------|------|-------------|
| system | -1 | Core cluster components (CNI, gateway, certificates) |
| platform | 0 | Platform services (secrets, auth, GitOps, VPN) |
| monitoring | 1 | Observability stack (metrics, logs, dashboards) |
| applications | 1 | End-user applications and services |
| smarthome | 2 | Smart home automation stack |

## Sync Wave Order

| Wave | Services | Purpose |
|------|----------|---------|
| -10 | AppProjects | Project definitions |
| -3 | cilium | CNI networking |
| -2 | kgateway | External traffic routing (Envoy on hostNetwork) |
| 0 | cert-manager, hubble-ui, vault, external-secrets | TLS, secret management |
| 1 | argocd | GitOps platform |
| 2 | tailscale, vault-secrets-generator, monitoring stack | VPN, secret generation, observability |
| 3 | authelia, mosquitto | SSO, MQTT broker |
| 4 | external-services, transmission, claude-code, soju, gamja, zigbee2mqtt | End-user services |
| 5 | home-assistant | Depends on mosquitto + zigbee2mqtt |

## Adding New Applications

1. Add chart to `kubernetes/apps/<name>/`
2. Add values file at `kubernetes/apps/<name>/values/homelab.yaml`
3. Add entry to appropriate parent in `app-of-apps/values.yaml`:
   ```yaml
   parents:
     platform:  # or system/monitoring/applications/smarthome
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
Internet → Cloudflare → Kyiv Router → WireGuard → kgateway Envoy (hostNetwork DaemonSet) → Services
```

TLS automated via cert-manager + Let's Encrypt + Cloudflare DNS-01.
