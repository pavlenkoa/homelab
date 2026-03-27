{{- define "common.basic-auth" -}}
{{- if .Values.basicAuth.enabled }}
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ .Values.externalSecret.secretName }}
  namespace: {{ .Release.Namespace }}
spec:
  refreshInterval: {{ .Values.externalSecret.refreshInterval | default "1h" }}
  secretStoreRef:
    name: {{ .Values.vault.secretStoreName }}
    kind: ClusterSecretStore
  target:
    name: {{ .Values.externalSecret.secretName }}
    creationPolicy: Owner
  data:
    - secretKey: .htpasswd
      remoteRef:
        key: {{ .Values.vault.secretPath }}
        property: {{ .Values.vault.htpasswdProperty | default "htpasswd" }}
---
apiVersion: gateway.kgateway.dev/v1alpha1
kind: TrafficPolicy
metadata:
  name: {{ .Values.basicAuth.targetRoute }}-auth
  namespace: {{ .Release.Namespace }}
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      name: {{ .Values.basicAuth.targetRoute }}
  basicAuth:
    secretRef:
      name: {{ .Values.externalSecret.secretName }}
      namespace: {{ .Release.Namespace }}
{{- end }}
{{- end -}}
