{{/*
ArgoCD Application template helper with global and project defaults
*/}}
{{- define "app-of-apps.application" -}}
{{- $root := index . 0 -}}
{{- $app := index . 1 -}}
{{- $projectName := index . 2 -}}
{{- $projectConfig := index . 3 -}}
{{- $global := $root.Values.global -}}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ $app.name }}
  namespace: argocd
  finalizers:
    {{- range ($app.finalizers | default $global.finalizers) }}
    - {{ . }}
    {{- end }}
spec:
  project: {{ $projectName }}
  source:
    repoURL: {{ (($app.repository).url) | default $global.repository.url }}
    targetRevision: {{ (($app.repository).targetRevision) | default $global.repository.targetRevision }}
    path: {{ $app.path }}
    {{- if $app.helm }}
    helm:
      {{- if $app.helm.valueFiles }}
      valueFiles:
        {{- if kindIs "slice" $app.helm.valueFiles }}
        {{- range $app.helm.valueFiles }}
        - {{ . }}
        {{- end }}
        {{- else }}
        - {{ $app.helm.valueFiles }}
        {{- end }}
      {{- end }}
      {{- if $app.helm.values }}
      values: |
        {{- $app.helm.values | nindent 8 }}
      {{- end }}
      {{- if $app.helm.parameters }}
      parameters:
        {{- range $app.helm.parameters }}
        - name: {{ .name }}
          value: {{ .value | quote }}
        {{- end }}
      {{- end }}
    {{- end }}
  destination:
    server: {{ (($app.destination).server) | default $global.destination.server }}
    namespace: {{ $app.namespace | default "default" }}
  syncPolicy:
    {{- $syncPolicy := mergeOverwrite (deepCopy $global.syncPolicy) ($projectConfig.syncPolicy | default dict) ($app.syncPolicy | default dict) }}
    automated:
      prune: {{ $syncPolicy.automated.prune }}
      selfHeal: {{ $syncPolicy.automated.selfHeal }}
    syncOptions:
      {{- range $syncPolicy.syncOptions }}
      - {{ . }}
      {{- end }}
    retry:
      limit: {{ $syncPolicy.retry.limit }}
      backoff:
        duration: {{ $syncPolicy.retry.backoff.duration }}
        factor: {{ $syncPolicy.retry.backoff.factor }}
        maxDuration: {{ $syncPolicy.retry.backoff.maxDuration }}
{{- end }}