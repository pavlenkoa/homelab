{{/*
ArgoCD Application template helper with global and project defaults
Supports external chart repositories with values from homelab repo using multiple sources
*/}}
{{- define "app-of-apps.application" -}}
{{- $root := index . 0 -}}
{{- $app := index . 1 -}}
{{- $projectName := index . 2 -}}
{{- $projectConfig := index . 3 -}}
{{- $global := $root.Values.global -}}
{{- $appRepoURL := (($app.repository).url) | default $global.repository.url -}}
{{- $useMultipleSources := and ($app.repository).url (ne $appRepoURL $global.repository.url) -}}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ $app.name }}
  namespace: argocd
  {{- if or $app.annotations $global.annotations }}
  annotations:
    {{- with $global.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $app.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
  finalizers:
    {{- range ($app.finalizers | default $global.finalizers) }}
    - {{ . }}
    {{- end }}
spec:
  project: {{ $projectName }}
  {{- if $useMultipleSources }}
  {{- /* Multiple sources: chart from external repo, values from homelab repo */}}
  sources:
    - repoURL: {{ $appRepoURL }}
      targetRevision: {{ (($app.repository).targetRevision) | default $global.repository.targetRevision }}
      path: {{ $app.path }}
      {{- if $app.helm }}
      helm:
        {{- if $app.helm.valueFiles }}
        valueFiles:
          {{- if kindIs "slice" $app.helm.valueFiles }}
          {{- range $app.helm.valueFiles }}
          - $values/{{ . }}
          {{- end }}
          {{- else }}
          - $values/{{ $app.helm.valueFiles }}
          {{- end }}
        {{- end }}
        {{- if $app.helm.values }}
        values: |
          {{- $app.helm.values | nindent 10 }}
        {{- end }}
        {{- if $app.helm.parameters }}
        parameters:
          {{- range $app.helm.parameters }}
          - name: {{ .name }}
            value: {{ .value | quote }}
          {{- end }}
        {{- end }}
      {{- end }}
    - repoURL: {{ $global.repository.url }}
      targetRevision: {{ $global.repository.targetRevision }}
      ref: values
  {{- else }}
  {{- /* Single source: chart and values from same repo */}}
  source:
    repoURL: {{ $appRepoURL }}
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