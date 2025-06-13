# TODO

## Current Status: GitOps Infrastructure - FULLY OPERATIONAL ✅

**✅ Phases 1-3 COMPLETED** (Foundation + GitOps + Platform Services)
- **Kubernetes Cluster**: OrbStack native Kubernetes with LoadBalancer support
- **GitOps Platform**: ArgoCD with enterprise-grade App-of-Apps pattern (self-managed via GitOps)
- **Ingress Controller**: ingress-nginx v4.12.3 with LoadBalancer (IP: 198.19.249.2)
- **Certificate Management**: cert-manager v1.18.0 with Cloudflare DNS-01 + Let's Encrypt automation
- **Secret Management**: Vault + external-secrets-operator with automated Kubernetes auth
- **TLS Automation**: FULLY FUNCTIONAL - Let's Encrypt certificates via Cloudflare DNS-01
- **GitOps Management**: ArgoCD UI at https://argocd.pavlenko.io (with valid TLS certificate!)
- **Repository**: Public GitHub integration with automated sync
- **Template System**: Extensible App-of-Apps with global defaults and per-app overrides

**🎉 MAJOR ACHIEVEMENTS:**
- **Complete TLS Automation**: Let's Encrypt + Cloudflare DNS-01 + external-secrets integration
- **ArgoCD Self-Management**: ArgoCD manages itself via GitOps (enterprise pattern)
- **Vault Integration**: Automated Kubernetes auth setup with external-secrets policies
- **Security Excellence**: No hardcoded secrets, all tokens stored in Vault
- **Professional Patterns**: Industry-standard configurations using work-proven patterns

**🎉 PHASE 4 PROGRESS - External Services Integration ✅ COMPLETED**
- **✅ External Services Chart**: Created external-services Helm chart for hybrid Docker→K8s migration
- **✅ Service without Selector + EndpointSlice**: Implemented proper K8s pattern for external backends
- **✅ ArgoCD Configuration**: Fixed EndpointSlice exclusions to allow external service management  
- **✅ Emby Integration**: Successfully proxying Docker Compose Emby (192.168.88.2:8096) → https://emby.pavlenko.io
- **✅ TLS Automation**: External services get automatic Let's Encrypt certificates via cert-manager
- **✅ GitOps Management**: All external service configs managed through ArgoCD + Git

**🚀 READY: Phase 4** - Testing and alignment of Authelia deployment, then monitoring stack

**💡 NEXT SESSION PRIORITIES:**
1. **Commit and Push Current Changes**: 
   - Complete Authelia wrapper chart implementation ready for testing
   - Auto-generated passwords with argon2id hashing
   - Standardized logging format matching vault pattern
2. **Test Authelia Deployment**: Deploy and debug Authelia wrapper chart (expect initial errors)
   - Validate pre-install job and secret generation in Vault
   - Debug any chart template or configuration issues  
   - Test external-secrets sync and secret mounting
   - Configure ingress, TLS, and test admin login
   - Set up OIDC integration and validate SSO workflow
3. **Deploy More External Services**: Add Transmission via external-services pattern
4. **Internal DNS Resolution**: Investigate local network DNS for *.pavlenko.io domains
   - Option A: MikroTik + Consul integration for service discovery
   - Option B: external-dns with MikroTik RouterOS API integration
   - Option C: Local DNS override solutions (dnsmasq, router configuration)
5. **Monitoring Stack**: Deploy VictoriaMetrics + Grafana using established wrapper chart pattern

---

## 🔧 Standardized Wrapper Chart Pattern

We've established a pattern for creating wrapper charts that handle secret generation and upstream chart integration. This provides consistency and eliminates manual secret management.

### **Authelia Wrapper Chart Implementation** ✅ COMPLETED

**Chart Structure:**
```
kubernetes/platform/charts/authelia/
├── Chart.yaml                     # Wrapper chart with upstream dependency (v0.10.12)
├── charts/authelia-0.10.12.tgz   # Downloaded upstream chart
├── templates/
│   ├── _helpers.tpl               # Chart helper functions
│   ├── serviceaccount.yaml        # Service account for pre-install job
│   ├── rbac.yaml                  # RBAC for cross-namespace secret access
│   ├── pre-install-job.yaml       # Secret generation in Vault with argon2id
│   └── external-secret.yaml       # Vault → K8s secret sync
└── values.yaml                    # Wrapper configuration + upstream values
```

**Key Components:**

1. **Chart.yaml** - Dependencies on upstream Authelia chart v0.10.12
2. **Pre-install Job** - Generates secrets in Vault with argon2id password hashing
3. **External Secret** - Syncs secrets from Vault to Kubernetes (12 secrets total)
4. **RBAC** - Allows cross-namespace secret access for external-secrets
5. **Values** - Configures both wrapper and upstream chart with file backend

**Secret Generation Strategy:**
- **Pre-install Helm hook** generates secrets in Vault (idempotent, standardized logging)
- **Auto-generated passwords** using `openssl rand -base64 32` (no manual input)
- **Argon2id hashing** with Authelia file backend parameters (`m=512KB, t=1, p=8`)
- **Vault token** sourced from `vault-unseal-keys` secret in vault namespace
- **External-secrets** pulls generated secrets into Kubernetes
- **Upstream chart** uses `existingSecret` pattern with file paths

**Benefits:**
- ✅ **Fully declarative** - No manual secret management
- ✅ **GitOps ready** - Everything in Git, secrets auto-generated
- ✅ **Reusable pattern** - Same approach for all services
- ✅ **Environment agnostic** - Works across dev/staging/prod
- ✅ **Secure** - Secrets never in Git, generated in Vault
- ✅ **Professional logging** - Matches vault chart logging format
- ✅ **Password security** - Argon2id with proper parameters

**Implementation Status:** ✅ COMPLETED
1. ✅ Create wrapper chart structure
2. ✅ Add upstream authelia chart dependency
3. ✅ Implement pre-install secret generation job with argon2id
4. ✅ Create external-secret for Vault integration
5. ✅ Configure upstream chart to use generated secrets
6. ✅ Add RBAC for cross-namespace access
7. ⏳ **NEXT**: Test deployment and debug any issues

**Next Services to Migrate:**
- Authelia (authentication)
- VictoriaMetrics (monitoring)
- Grafana (visualization)
- Future applications

This pattern will be our standard for all Kubernetes service deployments.

---

## OrbStack Kubernetes Migration Plan

### Phase 1: Kubernetes Foundation Setup ✅ COMPLETED
- [x] **Enable OrbStack Kubernetes cluster**:
  - [x] Configure OrbStack Kubernetes via UI (one-click setup)
  - [x] Verify cluster connectivity: `kubectl get nodes`
  - [x] Install Helm package manager
  - [x] Configure kubectl context for homelab cluster (renamed to 'homelab')
- [x] **Deploy ingress-nginx and cert-manager** (replaced Cilium - not supported on OrbStack):
  - [x] Create App-of-Apps configuration for cert-manager v1.16.2
  - [x] Create App-of-Apps configuration for ingress-nginx v4.12.0
  - [x] Create `kubernetes/infrastructure/values/homelab/cert-manager.yaml` values
  - [x] Create `kubernetes/infrastructure/values/homelab/ingress-nginx.yaml` values
  - [x] Configure NodePort access (30080/30443) for external connectivity
  - [x] Enable Prometheus metrics for monitoring integration

### Phase 2: ArgoCD GitOps Setup ✅ COMPLETED
- [x] **Deploy ArgoCD to Kubernetes cluster**:
  - [x] Install ArgoCD via Helm with NodePort access (http://localhost:30081)
  - [x] Configure insecure mode for local development
  - [x] Set up admin access: admin / BQUb-QTq3RkNkNUm
  - [x] Connect ArgoCD to https://github.com/pavlenkoa/homelab.git repository (public)
- [x] **Create App-of-Apps Helm Chart**:
  - [x] Create `kubernetes/app-of-apps/Chart.yaml` 
  - [x] Create `kubernetes/app-of-apps/templates/_application.tpl` helper with global defaults
  - [x] Create `kubernetes/app-of-apps/templates/applications.yaml` generator
  - [x] Create `kubernetes/app-of-apps/values.yaml` with global defaults
  - [x] Create `kubernetes/app-of-apps/values/homelab.yaml` with service definitions
  - [x] Deploy app-of-apps with extensible template system
  - [x] Verify GitOps workflow: Git push → ArgoCD auto-sync → Cluster update
  - [x] **Enhanced App-of-Apps Features**:
    - [x] Global defaults with per-application overrides
    - [x] Support for multiple Helm value files and inline values
    - [x] Configurable sync policies, destinations, and repositories
    - [x] Enterprise-grade template system for scalability

### Phase 3: Platform Services - Core Infrastructure ✅ COMPLETED
- [x] **Deploy cert-manager + ingress-nginx** (replaced Caddy):
  - [x] Create `kubernetes/infrastructure/charts/cert-manager/` chart (v1.18.0)
  - [x] Create `kubernetes/infrastructure/charts/ingress-nginx/` chart (v4.12.3)
  - [x] Create `kubernetes/infrastructure/values/homelab/cert-manager.yaml` values
  - [x] Create `kubernetes/infrastructure/values/homelab/ingress-nginx.yaml` values
  - [x] Configure LoadBalancer service for OrbStack compatibility
  - [x] Deploy via ArgoCD App-of-Apps pattern
  - [x] Configure external DNS servers for cert-manager DNS01 self-check
  - [x] Configure Let's Encrypt ClusterIssuer with Cloudflare DNS-01 challenge
- [x] **Deploy HashiCorp Vault**:
  - [x] Create `kubernetes/platform/charts/vault/` chart using HashiCorp Helm chart
  - [x] Create `kubernetes/platform/values/homelab/vault.yaml` values  
  - [x] Deploy via ArgoCD: Vault is running and healthy
  - [x] Configure KV v2 secret engine: `kv/`
  - [x] Configure Cloudflare API token for cert-manager DNS-01 challenge
  - [x] Automate Vault Kubernetes auth configuration with external-secrets policies
  - [ ] Set up Vault UI access via ingress (next phase)
- [x] **Deploy External Secrets Operator**:
  - [x] Enable external-secrets in app-of-apps configuration
  - [x] Create `kubernetes/platform/values/homelab/external-secrets.yaml` values
  - [x] Configure Vault ClusterSecretStore with Kubernetes auth
  - [x] Create ExternalSecret for Cloudflare API token in cert-manager namespace
  - [x] Test secret synchronization from Vault to K8s secrets
  - [x] Implement ArgoCD sync waves for proper CRD timing
  - [x] Fix API version compatibility (external-secrets.io/v1)
- [x] **Complete TLS Automation Pipeline**:
  - [x] End-to-end automation: Vault → external-secrets → cert-manager → Let's Encrypt
  - [x] Automated certificate issuance for argocd.pavlenko.io domain
  - [x] ArgoCD ingress with valid Let's Encrypt certificate
  - [x] Professional TLS configuration using extraTls pattern
  - [x] ArgoCD self-management via GitOps (enterprise pattern)

### Phase 4: Platform Services - Monitoring & Authentication (Using Wrapper Chart Pattern)
- [x] **Deploy Authelia** (Priority 1 - Wrapper Chart Pattern) - INITIAL SETUP COMPLETE:
  - [x] Create `kubernetes/platform/charts/authelia/` wrapper chart
  - [x] Add upstream authelia chart dependency in Chart.yaml (v0.10.12)
  - [x] Implement pre-install job for secret generation in Vault with argon2id hashing
  - [x] Create external-secret template for Vault → K8s integration
  - [x] Configure wrapper values.yaml with upstream chart configuration
  - [x] Create `kubernetes/platform/values/homelab/authelia.yaml` environment values
  - [x] Implement auto-generated admin passwords (no manual configuration)
  - [x] Use standardized logging format matching vault chart pattern
  - [x] Configure argon2id password hashing with Authelia file backend parameters
  - [x] Set up RBAC for cross-namespace secret access
  - [ ] **NEXT SESSION - TESTING & ALIGNMENT**:
    - [ ] Test Authelia deployment via ArgoCD (expect errors - first deployment)
    - [ ] Debug and fix any chart template issues
    - [ ] Validate secret generation and external-secrets sync
    - [ ] Configure Redis integration (subchart enabled in chart)
    - [ ] Set up ingress and TLS for auth.pavlenko.io
    - [ ] Test admin login with auto-generated credentials
    - [ ] Set up OIDC integration with Immich
    - [ ] Validate SSO workflow end-to-end
    - [ ] Add Authelia to app-of-apps for GitOps deployment
- [ ] **Deploy VictoriaMetrics Stack** (Wrapper Chart Pattern):
  - [ ] Create `kubernetes/platform/charts/victoriametrics/` wrapper chart
  - [ ] Use VM Helm charts as dependency
  - [ ] Implement secret generation for authentication
  - [ ] Create `kubernetes/platform/values/homelab/victoriametrics.yaml` values
  - [ ] Configure persistent storage for metrics data
- [ ] **Deploy VictoriaLogs** (Wrapper Chart Pattern):
  - [ ] Create `kubernetes/platform/charts/victorialogs/` wrapper chart  
  - [ ] Use VM charts as dependency
  - [ ] Implement log retention and storage configuration
  - [ ] Create `kubernetes/platform/values/homelab/victorialogs.yaml` values
- [ ] **Deploy Grafana** (Wrapper Chart Pattern):
  - [ ] Create `kubernetes/platform/charts/grafana/` wrapper chart
  - [ ] Use upstream Grafana Helm chart as dependency
  - [ ] Generate admin password and API keys in Vault
  - [ ] Create `kubernetes/platform/values/homelab/grafana.yaml` values
  - [ ] Configure VictoriaMetrics and VictoriaLogs data sources
  - [ ] Import monitoring dashboards from current Docker setup
  - [ ] Set up alerting rules and notification channels
- [ ] **Deploy Alloy (Metrics Collection)** (Wrapper Chart Pattern):
  - [ ] Create `kubernetes/platform/charts/alloy/` wrapper chart
  - [ ] Use Grafana Helm chart as dependency
  - [ ] Generate collection credentials in Vault
  - [ ] Create `kubernetes/platform/values/homelab/alloy.yaml` values  
  - [ ] Configure metrics collection from Kubernetes and external sources
  - [ ] Set up metrics forwarding to VictoriaMetrics

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
