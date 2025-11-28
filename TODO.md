# TODO List

## Current Status: Authentication & External Services ✅ COMPLETED

**Infrastructure is fully operational:**
- ✅ Kubernetes cluster with GitOps (ArgoCD)
- ✅ Certificate management (cert-manager + Let's Encrypt)
- ✅ Secret management (Vault + external-secrets)
- ✅ Authentication (Authelia SSO with 2FA)
- ✅ External services (Emby, Transmission) with secure forward-auth

## High Priority

### Monitoring Stack Deployment
- [ ] **VictoriaMetrics**: 
  - Metrics storage with wrapper chart pattern
  - No ingress needed (internal ClusterIP)
  - Persistent storage on Mac Mini local volumes
- [ ] **Grafana**: 
  - Visualization with ingress (grafana.pavlenko.io)
  - Authelia OIDC integration for SSO login
  - Data source configuration for VictoriaMetrics and Loki
- [ ] **Loki**: 
  - Log aggregation (replacing VictoriaLogs)
  - No ingress needed (internal ClusterIP)
  - 30-day log retention with local storage on Mac Mini
- [ ] **Alloy**: 
  - Metrics/logs collection agent
  - Collect from Kubernetes services and external Docker services
  - Forward to VictoriaMetrics and Loki

### Monitoring Configuration
- [ ] **Dashboards**: Import and adapt dashboards from current Docker setup
- [ ] **Alerts**: Configure alert rules and notification channels
- [ ] **Data Sources**: Configure Grafana connections to VictoriaMetrics and Loki

### Application Services
- [ ] **n8n**:
  - Workflow automation platform with wrapper chart
  - Local-only access (no SSO/external exposure)
  - Persistent storage for workflow data
  - Ingress: n8n.pavlenko.io (router DNS override to 192.168.139.2)
- [ ] **Immich**:
  - Photo management service with wrapper chart
  - OIDC integration with Authelia
  - Persistent storage for photos and metadata
  - Ingress: photos.pavlenko.io (already configured in Authelia)
- [ ] **OIDC Testing**: Validate end-to-end SSO workflow with Immich

## Medium Priority

### ArgoCD Optimization  
- [ ] Fix apps going out of sync issues
- [ ] Configure proper health checks for all applications
- [ ] Optimize sync policies and refresh intervals

### Storage and Persistence
- [ ] Configure local storage classes for Mac Mini persistent volumes
- [ ] Set up log retention policies (30 days for Loki)
- [ ] Configure metrics retention in VictoriaMetrics

## Low Priority

### Documentation
- [ ] Update ARCHITECTURE.md for final K8s setup
- [ ] Service URLs and access instructions  
- [ ] Operational runbooks for monitoring and maintenance

## Completed ✅
- [x] Vault deployment and configuration
- [x] External secrets integration  
- [x] ArgoCD GitOps platform
- [x] Certificate management with Let's Encrypt
- [x] Authelia SSO authentication (complete with 2FA)
- [x] External services chart with secure forward-auth
- [x] Transmission deployment with mandatory authentication
- [x] Test service (test.pavlenko.io) with working forward-auth

## Architecture Decisions
- **No ingress for internal services**: VictoriaMetrics, Loki (security + simplicity)
- **Local storage**: Mac Mini volumes for metrics/logs (no NFS complexity)
- **Grafana as single entry point**: All monitoring access through Grafana with SSO
- **30-day retention**: Balance between storage usage and operational needs
- **Wrapper chart pattern**: Consistent secret management across all services

---

**Next Session Goal**: Deploy monitoring stack (VictoriaMetrics + Grafana + Loki + Alloy) with proper storage configuration and Grafana OIDC integration.