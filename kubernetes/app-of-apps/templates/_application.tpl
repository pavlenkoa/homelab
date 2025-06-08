{{/*
ArgoCD Application template helper
*/}}
{{- define "app-of-apps.application" }}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ .name }}
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: {{ .repoURL | default "https://github.com/pavlenkoa/homelab.git" }}
    targetRevision: {{ .targetRevision | default "HEAD" }}
    path: {{ .path }}
    {{- if .helm }}
    helm:
      valueFiles:
        - {{ .helm.valueFiles }}
    {{- end }}
  destination:
    server: https://kubernetes.default.svc
    namespace: {{ .namespace | default "default" }}
  syncPolicy:
    automated:
      prune: {{ .syncPolicy.prune | default true }}
      selfHeal: {{ .syncPolicy.selfHeal | default true }}
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
{{- end }}