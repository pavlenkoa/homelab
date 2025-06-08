# TODO

## OrbStack Kubernetes Migration Plan

### Phase 1: Kubernetes Foundation Setup
- [ ] **Enable OrbStack Kubernetes cluster**:
  - [ ] Configure OrbStack Kubernetes via UI (one-click setup)
  - [ ] Verify cluster connectivity: `kubectl get nodes`
  - [ ] Install Helm package manager
  - [ ] Configure kubectl context for homelab cluster
- [ ] **Deploy Cilium CNI with Hubble observability**:
  - [ ] Create `kubernetes/infrastructure/charts/cilium/` chart
  - [ ] Create `kubernetes/infrastructure/values/homelab/cilium.yaml` values
  - [ ] Replace default CNI with Cilium (helm upgrade cilium cilium/cilium)
  - [ ] Enable Hubble for network observability and flow monitoring
  - [ ] Configure Cilium Service Mesh for L7 traffic management
  - [ ] Verify Cilium installation: `cilium status`

### Phase 2: ArgoCD GitOps Setup  
- [ ] **Deploy ArgoCD to Kubernetes cluster**:
  - [ ] Install ArgoCD via Helm (helm install argocd argo/argo-cd -n argocd --create-namespace)
  - [ ] Configure Caddy ingress for ArgoCD web UI
  - [ ] Set up admin access: `kubectl get secret argocd-initial-admin-secret`
  - [ ] Connect ArgoCD to https://github.com/pavlenkoa/homelab.git repository
- [ ] **Create App-of-Apps Helm Chart**:
  - [ ] Create `kubernetes/app-of-apps/Chart.yaml` 
  - [ ] Create `kubernetes/app-of-apps/templates/_application.tpl` helper
  - [ ] Create `kubernetes/app-of-apps/templates/applications.yaml` generator
  - [ ] Create `kubernetes/app-of-apps/values/homelab.yaml` with service definitions
  - [ ] Deploy app-of-apps: `helm install app-of-apps ./kubernetes/app-of-apps`

### Phase 3: Platform Services - Core Infrastructure
- [ ] **Deploy Caddy Ingress Controller**:
  - [ ] Create `kubernetes/infrastructure/charts/caddy/` chart 
  - [ ] Create `kubernetes/infrastructure/values/homelab/caddy.yaml` values
  - [ ] Configure auto-TLS with Let's Encrypt
  - [ ] Set up ingress rules for all services
  - [ ] Verify external access: `https://homelab.domain.com`
- [ ] **Deploy HashiCorp Vault**:
  - [ ] Create `kubernetes/platform/charts/vault/` chart using HashiCorp Helm chart
  - [ ] Create `kubernetes/platform/values/homelab/vault.yaml` values  
  - [ ] Install Vault: `helm install vault hashicorp/vault`
  - [ ] Initialize and unseal Vault cluster: `kubectl exec vault-0 -- vault operator init`
  - [ ] Configure secret engines (KV v2, PKI, Transit)
  - [ ] Set up Vault UI access via Caddy ingress
- [ ] **Deploy External Secrets Operator**:
  - [ ] Create `kubernetes/platform/charts/external-secrets/` chart
  - [ ] Create `kubernetes/platform/values/homelab/external-secrets.yaml` values
  - [ ] Install ESO: `helm install external-secrets external-secrets/external-secrets`
  - [ ] Configure Vault SecretStore and ClusterSecretStore
  - [ ] Test secret synchronization from Vault to K8s secrets

### Phase 4: Platform Services - Monitoring & Authentication
- [ ] **Deploy VictoriaMetrics Stack**:
  - [ ] Create `kubernetes/platform/charts/victoriametrics/` chart using VM Helm charts
  - [ ] Create `kubernetes/platform/values/homelab/victoriametrics.yaml` values
  - [ ] Install VictoriaMetrics: `helm install vm vm/victoria-metrics-cluster`
  - [ ] Configure persistent storage for metrics data
- [ ] **Deploy VictoriaLogs**:
  - [ ] Create `kubernetes/platform/charts/victorialogs/` chart
  - [ ] Create `kubernetes/platform/values/homelab/victorialogs.yaml` values
  - [ ] Install VictoriaLogs: `helm install vlogs vm/victoria-logs-single`
  - [ ] Configure log retention and storage policies
- [ ] **Deploy Grafana**:
  - [ ] Create `kubernetes/platform/charts/grafana/` chart using Grafana Helm chart
  - [ ] Create `kubernetes/platform/values/homelab/grafana.yaml` values
  - [ ] Install Grafana: `helm install grafana grafana/grafana`
  - [ ] Configure VictoriaMetrics and VictoriaLogs data sources
  - [ ] Import monitoring dashboards from current Docker setup
  - [ ] Set up alerting rules and notification channels
- [ ] **Deploy Alloy (Metrics Collection)**:
  - [ ] Create `kubernetes/platform/charts/alloy/` chart using Grafana Helm chart
  - [ ] Create `kubernetes/platform/values/homelab/alloy.yaml` values
  - [ ] Install Alloy: `helm install alloy grafana/alloy`
  - [ ] Configure metrics collection from Kubernetes and external sources
  - [ ] Set up metrics forwarding to VictoriaMetrics
- [ ] **Deploy Authelia**:
  - [ ] Create `kubernetes/platform/charts/authelia/` custom chart
  - [ ] Create `kubernetes/platform/values/homelab/authelia.yaml` values
  - [ ] Configure Redis StatefulSet for session storage
  - [ ] Migrate authentication configuration from Docker Compose
  - [ ] Set up OIDC integration with other services
  - [ ] Configure Caddy integration for SSO

### Phase 5: Application Services Migration
- [ ] **Deploy Immich (Photo Management)**:
  - [ ] Create `kubernetes/applications/charts/immich/` chart
  - [ ] Create `kubernetes/applications/values/homelab/immich.yaml` values
  - [ ] Configure PostgreSQL StatefulSet with persistent storage
  - [ ] Configure Redis for caching and job queues
  - [ ] Set up persistent volume for photo uploads
  - [ ] Configure NFS connection to Kyiv media storage
  - [ ] Migrate OAuth configuration from Docker Compose
  - [ ] Test photo upload and external library scanning
- [ ] **Deploy Emby (Media Server)**:
  - [ ] Create `kubernetes/applications/charts/emby/` chart  
  - [ ] Create `kubernetes/applications/values/homelab/emby.yaml` values
  - [ ] Configure persistent storage for Emby data
  - [ ] Set up NFS mounts for media access from Kyiv
  - [ ] Configure hardware transcoding (if supported)
  - [ ] Test media streaming and transcoding functionality

### Phase 6: Advanced Platform Features  
- [ ] **Deploy Hubble UI (Network Observability)**:
  - [ ] Create `kubernetes/platform/charts/hubble-ui/` chart
  - [ ] Create `kubernetes/platform/values/homelab/hubble-ui.yaml` values
  - [ ] Install Hubble UI: `helm install hubble-ui cilium/hubble-ui`
  - [ ] Configure network flow visualization and monitoring
- [ ] **Deploy HashiCorp Consul (Optional)**:
  - [ ] Create `kubernetes/platform/charts/consul/` chart using HashiCorp Helm chart
  - [ ] Create `kubernetes/platform/values/homelab/consul.yaml` values
  - [ ] Install Consul: `helm install consul hashicorp/consul`
  - [ ] Configure service mesh and service discovery
  - [ ] Set up Consul Connect for service-to-service encryption
- [ ] **Deploy HashiCorp Boundary (Optional)**:
  - [ ] Create `kubernetes/platform/charts/boundary/` chart
  - [ ] Create `kubernetes/platform/values/homelab/boundary.yaml` values
  - [ ] Configure secure remote access and session recording
  - [ ] Integrate with Vault for dynamic credentials

### Phase 7: Hybrid Architecture (Kubernetes + Docker)
- [ ] **Kyiv Raspberry Pi integration**:
  - [ ] Keep Transmission on Docker (storage-local BitTorrent)
  - [ ] Update Alloy configuration to collect metrics from Kyiv Docker services
  - [ ] Configure NFS exports for Kubernetes persistent volumes
  - [ ] Set up secure tunneling for cross-location service communication
- [ ] **Service placement optimization**:
  - [ ] CPU-intensive workloads → Mac Mini Kubernetes (Emby transcoding, VictoriaMetrics)
  - [ ] Storage-heavy services → Kyiv Docker/NFS (Transmission, media storage)
  - [ ] Control plane and management → Kubernetes (ArgoCD, Grafana, Vault)
  - [ ] Cross-location monitoring → Kubernetes Alloy agents → Kyiv Docker metrics

### Phase 8: GitOps Workflow Optimization
- [ ] **Complete ArgoCD GitOps Integration**:
  - [ ] Ensure all services deployed via ArgoCD App-of-Apps pattern
  - [ ] Configure automatic sync policies and health checks
  - [ ] Set up ArgoCD notifications and alerting
  - [ ] Test rollback and disaster recovery procedures
- [ ] **Environment Management**:
  - [ ] Create staging environment values (`kubernetes/*/values/staging/`)
  - [ ] Implement environment promotion workflows
  - [ ] Set up branch-based deployment strategies
- [ ] **Monitoring and Alerting Integration**:
  - [ ] Configure Grafana alerting for Kubernetes cluster health
  - [ ] Set up alerts for ArgoCD sync failures and application health
  - [ ] Create runbooks for common operational tasks

### Phase 9: Migration Strategy and Testing
- [ ] **Parallel deployment testing**:
  - [ ] Run services in both Docker and Kubernetes
  - [ ] Compare performance and resource usage
  - [ ] Test failover and disaster recovery scenarios
  - [ ] Validate all functionality matches Docker deployment
- [ ] **Gradual migration approach**:
  - [ ] Start with stateless services (Caddy, Authelia)
  - [ ] Move monitoring stack (already stateless design)
  - [ ] Migrate stateful services last (Immich with data)
  - [ ] Keep critical services in Docker until K8s proven stable
- [ ] **Documentation and runbooks**:
  - [ ] Update ARCHITECTURE.md for hybrid K8s/Docker model
  - [ ] Create operational runbooks for common tasks
  - [ ] Document troubleshooting procedures
  - [ ] Update deployment workflows and commands

## Kubernetes Directory Structure

### Final Structure Decision: Centralized Values Pattern
Based on proven enterprise patterns and professional experience transfer, using centralized structure similar to established company practices:

```
homelab/
├── docker-compose/              # Current Docker setup (preserved)
│   ├── _base/
│   ├── wroclaw/
│   ├── kyiv/
│   └── scripts/                 # Docker Compose automation
│       ├── deploy               # Main deployment CLI
│       ├── Makefile             # Make command wrapper
│       ├── template.py          # Jinja2 templating
│       └── requirements.txt     # Python dependencies
├── kubernetes/                  # New Kubernetes manifests
│   ├── infrastructure/          # Core cluster infrastructure
│   │   ├── charts/             # Helm charts for infrastructure
│   │   │   ├── cilium/         # CNI with Hubble
│   │   │   └── caddy/          # Ingress controller with auto-TLS
│   │   ├── templates/          # Jinja2 templates (optional, complex cases)
│   │   │   ├── caddy.yaml.j2
│   │   │   └── cilium.yaml.j2
│   │   └── values/             # Environment-specific values
│   │       └── homelab/        # Primary environment
│   │           ├── cilium.yaml
│   │           ├── cert-manager.yaml # Optional if using Caddy auto-TLS
│   │           └── caddy.yaml
│   ├── platform/               # Platform services
│   │   ├── charts/
│   │   │   ├── vault/          # Secret management
│   │   │   ├── external-secrets/ # Vault integration
│   │   │   ├── consul/         # Service mesh and discovery
│   │   │   ├── authelia/       # Authentication
│   │   │   ├── grafana/        # Visualisation & Notifications (new grafana includes extensive alerting)
│   │   │   ├── victoriametrics/ # Metrics storage
│   │   │   ├── victorialogs/   # Logs storage
│   │   │   ├── alloy/          # Metrics collection agent
│   │   │   ├── hubble-ui/      # Cilium network observability
│   │   │   └── boundary/       # Secure access (optional)
│   │   ├── templates/          # Platform-specific Jinja2 templates
│   │   └── values/
│   │       └── homelab/
│   │           ├── vault.yaml
│   │           ├── external-secrets.yaml
│   │           ├── consul.yaml
│   │           ├── authelia.yaml
│   │           ├── grafana.yaml
│   │           ├── victoriametrics.yaml
│   │           ├── victorialogs.yaml
│   │           ├── alloy.yaml
│   │           ├── hubble-ui.yaml
│   │           └── boundary.yaml
│   ├── applications/           # Business applications
│   │   ├── charts/
│   │   │   ├── immich/         # Photo management
│   │   │   └── emby/           # Media server
│   │   ├── templates/          # Application-specific templates
│   │   └── values/
│   │       └── homelab/
│   │           ├── immich.yaml
│   │           └── emby.yaml
│   ├── app-of-apps/            # ArgoCD App of Apps pattern
│   │   ├── Chart.yaml          # Helm chart for generating ArgoCD apps
│   │   ├── templates/
│   │   │   ├── _application.tpl # Template helper for ArgoCD apps
│   │   │   └── applications.yaml # Dynamic ArgoCD app generation
│   │   └── values/
│   │       └── homelab.yaml    # Defines which apps to deploy
│   └── scripts/                # Templating and deployment automation
│       ├── template.py         # Jinja2 templating script
│       └── deploy.py           # Environment deployment script
└── docs/                       # Documentation (preserved)
```

### Benefits of This Structure
- **Professional alignment**: Matches enterprise patterns for skill transfer
- **Environment-first thinking**: Easy to see all services for an environment
- **Templating power**: Jinja2 generates values from infrastructure state
- **Scalable**: Can add staging/dev environments by adding new directories
- **Clear separation**: Charts, templates, and values cleanly separated
- **ArgoCD native**: App-of-apps pattern with Helm chart generation

### Templating Strategy
- **Optional Jinja2**: Use templates only for complex cases requiring cross-service values
- **Static values**: Most services use simple YAML values files
- **Environment generation**: Script can template entire environment from infrastructure state
- **Flexible granularity**: Template per service, per environment, or everything

### ArgoCD Application Structure
- **App-of-Apps Helm Chart**: Generates ArgoCD applications dynamically
- **Three-layer deployment**: Infrastructure → Platform → Applications
- **Environment-aware**: All apps point to correct environment values directory

### Success Criteria
- [ ] **Zero-downtime migration**: Services remain available during transition
- [ ] **Feature parity**: All current functionality preserved in Kubernetes
- [ ] **Improved scalability**: Better resource utilization on Mac Mini M4
- [ ] **Enhanced security**: Vault-managed secrets, service mesh, network policies
- [ ] **GitOps workflow**: All changes deployed through git commits
- [ ] **Monitoring excellence**: Better observability than current Docker setup
- [ ] **Disaster recovery**: Complete infrastructure as code in git

### Risk Mitigation
- [ ] **Rollback plan**: Ability to quickly return to Docker Compose
- [ ] **Resource monitoring**: Ensure 16GB RAM sufficient for Kubernetes overhead
- [ ] **Data backup**: Full backup before migration starts
- [ ] **Service isolation**: Prevent single component failure from affecting others
- [ ] **Gradual approach**: Phase-by-phase migration with validation at each step

---

## Current Status: Docker Compose Architecture ✅ COMPLETED

The current Docker Compose infrastructure is fully operational with:
- ✅ 2-location setup (Wrocław Mac Mini + Kyiv Raspberry Pi)
- ✅ All services migrated to docker-compose/ directory structure
- ✅ Professional CLI with service selection workflow
- ✅ Template processing and secret management
- ✅ GitOps-ready configuration management
- ✅ Comprehensive monitoring with VictoriaLogs + VictoriaMetrics

**Ready for Kubernetes migration while maintaining full Docker Compose fallback capability.**
