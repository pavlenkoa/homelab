# Vault Auto-Unseal Deployment Guide

This guide explains how to deploy Vault with automatic unsealing in your homelab Kubernetes cluster.

## Overview

The auto-unseal solution consists of:
1. **Vault server** in standalone mode with persistent storage
2. **RBAC configuration** allowing Vault to manage its unseal keys
3. **Initialization Job** that runs once to initialize Vault and create unseal keys
4. **Auto-unseal CronJob** that unseals Vault every 5 minutes if needed

## Deployment Steps

### 1. Deploy RBAC Configuration

First, deploy the service account and RBAC permissions:

```bash
kubectl apply -f kubernetes/platform/values/homelab/vault-rbac.yaml
```

### 2. Deploy Vault Server

Deploy Vault using your GitOps process or directly:

```bash
# If using ArgoCD
git add kubernetes/platform/values/homelab/vault.yaml
git commit -m "Add Vault auto-unseal configuration"
git push

# Or deploy directly with Helm
helm upgrade --install vault kubernetes/platform/charts/vault/ \
  --values kubernetes/platform/values/homelab/vault.yaml \
  --namespace vault --create-namespace
```

### 3. Run Initialization Job

Deploy and run the initialization job:

```bash
kubectl apply -f kubernetes/platform/values/homelab/vault-init-job.yaml
```

Monitor the job:

```bash
# Check job status
kubectl get jobs -n vault

# Check job logs
kubectl logs -n vault job/vault-init

# Verify unseal keys secret was created
kubectl get secret vault-unseal-keys -n vault
```

### 4. Verify Auto-Unseal

Check that Vault is running and unsealed:

```bash
# Check Vault pods
kubectl get pods -n vault

# Check Vault status
kubectl exec -n vault vault-0 -- vault status

# Check auto-unseal CronJob
kubectl get cronjobs -n vault
```

## Key Components

### Unseal Keys Secret

The `vault-unseal-keys` secret contains:
- `unseal-key-1` through `unseal-key-5`: Base64-encoded unseal keys
- `root-token`: Vault root token for administrative access

### Auto-Unseal Process

1. **Initialization Job**: Runs once when Vault is first deployed
   - Initializes Vault if not already initialized
   - Creates the unseal keys secret
   - Performs initial unseal

2. **CronJob**: Runs every 5 minutes
   - Checks if Vault is sealed
   - Unseals using keys from the secret
   - Handles pod restarts and cluster maintenance

## Security Considerations

### Production Recommendations

For production environments, consider:

1. **External Key Management**: Use cloud KMS (AWS KMS, Azure Key Vault, GCP KMS) for auto-unseal
2. **Secret Management**: Store unseal keys in external secret management system
3. **Backup Strategy**: Securely backup unseal keys and recovery keys
4. **Access Control**: Restrict access to the vault namespace
5. **Monitoring**: Set up alerts for Vault seal/unseal events

### Current Homelab Setup

The current configuration:
- ✅ Uses Kubernetes RBAC to limit permissions
- ✅ Stores keys in Kubernetes secrets (encrypted at rest)
- ✅ Automatic recovery from pod restarts
- ⚠️  Keys are accessible to anyone with cluster admin access
- ⚠️  No backup strategy for unseal keys

## Troubleshooting

### Common Issues

1. **Vault Won't Start**
   ```bash
   kubectl logs -n vault vault-0
   kubectl describe pod -n vault vault-0
   ```

2. **Initialization Job Fails**
   ```bash
   kubectl logs -n vault job/vault-init
   kubectl describe job -n vault vault-init
   ```

3. **Auto-Unseal Not Working**
   ```bash
   kubectl logs -n vault $(kubectl get pods -n vault -l app=vault-auto-unseal -o jsonpath='{.items[0].metadata.name}')
   ```

4. **Missing Unseal Keys Secret**
   ```bash
   # Check if secret exists
   kubectl get secret vault-unseal-keys -n vault
   
   # If missing, re-run initialization job
   kubectl delete job vault-init -n vault
   kubectl apply -f kubernetes/platform/values/homelab/vault-init-job.yaml
   ```

### Emergency Recovery

If you lose the unseal keys secret but still have access to the original keys:

```bash
# Recreate the secret manually (replace with your actual keys)
kubectl create secret generic vault-unseal-keys \
  --from-literal=unseal-key-1="YOUR_KEY_1" \
  --from-literal=unseal-key-2="YOUR_KEY_2" \
  --from-literal=unseal-key-3="YOUR_KEY_3" \
  --from-literal=unseal-key-4="YOUR_KEY_4" \
  --from-literal=unseal-key-5="YOUR_KEY_5" \
  --from-literal=root-token="YOUR_ROOT_TOKEN" \
  --namespace=vault
```

## Accessing Vault

### Get Root Token

```bash
kubectl get secret vault-unseal-keys -n vault -o jsonpath='{.data.root-token}' | base64 -d
```

### Port Forward to Access UI

```bash
kubectl port-forward -n vault service/vault 8200:8200
```

Then access: http://localhost:8200

### CLI Access

```bash
# Set environment variables
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN=$(kubectl get secret vault-unseal-keys -n vault -o jsonpath='{.data.root-token}' | base64 -d)

# Check status
vault status
```

## Monitoring

Consider adding these alerts to your monitoring stack:

1. **Vault Sealed Alert**: Alert when Vault becomes sealed
2. **Initialization Job Failure**: Alert when init job fails
3. **Auto-Unseal Job Failure**: Alert when CronJob fails
4. **Unseal Keys Secret Missing**: Alert when the secret is deleted

## Next Steps

1. **Set up Ingress**: Configure ingress for external access
2. **Configure Auth Methods**: Set up Kubernetes auth, OIDC, etc.
3. **Create Policies**: Define fine-grained access policies
4. **Backup Strategy**: Implement automated backup of Vault data
5. **External Secrets**: Integrate with External Secrets Operator