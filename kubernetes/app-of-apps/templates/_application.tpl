{{/*
ArgoCD Application template helper for child applications
Supports external chart repositories with values from homelab repo using multiple sources

Features:
- Auto-generated path: kubernetes/charts/<name> (if not specified)
- Auto-generated namespace: <name> (if not specified)
- Auto-generated valueFiles: values/<environment.name>.yaml
- Name prefixing with environment name (optional via environment.prefixNames)
- Uses shared helpers for syncPolicy, ignoreDifferences, annotations, finalizers

Merge order: childDefaults → layerConfig.childDefaults → app
*/}}
{{- define "app-of-apps.application" -}}
{{- $root := index . 0 -}}
{{- $app := index . 1 -}}
{{- $layerName := index . 2 -}}
{{- $layerConfig := index . 3 -}}
{{- $env := $root.Values.environment -}}
{{- $childDefaults := $root.Values.childDefaults -}}
{{- $layerChildDefaults := $layerConfig.childDefaults | default dict -}}
{{- /* Calculate effective layer name (used as ArgoCD project) */ -}}
{{- $effectiveLayerName := $layerName -}}
{{- if $layerConfig.layerName }}
  {{- $effectiveLayerName = $layerConfig.layerName -}}
{{- else if and $env.name $env.prefixNames }}
  {{- $effectiveLayerName = printf "%s-%s" $env.name $layerName -}}
{{- end }}
{{- /* Calculate effective application name */ -}}
{{- $effectiveAppName := $app.name -}}
{{- if and $env.name $env.prefixNames }}
  {{- $effectiveAppName = printf "%s-%s" $env.name $app.name -}}
{{- end }}
{{- /* Smart defaults */ -}}
{{- $appPath := $app.path | default (printf "kubernetes/charts/%s" $app.name) -}}
{{- $appNamespace := $app.namespace | default $app.name -}}
{{- $appRepoURL := (($app.repository).url) | default $root.Values.repository.url -}}
{{- $useMultipleSources := and ($app.repository).url (ne $appRepoURL $root.Values.repository.url) -}}
{{- /* Auto-generate valueFiles if not specified */ -}}
{{- $autoValueFile := printf "values/%s.yaml" $env.name -}}
{{- /* For external repos, use full path from homelab repo */ -}}
{{- $autoValueFileExternal := printf "kubernetes/charts/%s/values/%s.yaml" $app.name $env.name -}}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ $effectiveAppName }}
  namespace: argocd
  {{- include "app-of-apps.annotations" (list $childDefaults.annotations $layerChildDefaults.annotations $app.annotations) | nindent 2 }}
  {{- include "app-of-apps.finalizers" (list $app.finalizers $layerChildDefaults.finalizers $childDefaults.finalizers) | nindent 2 }}
spec:
  project: {{ $effectiveLayerName }}
  {{- if $useMultipleSources }}
  {{- /* Multiple sources: chart from external repo, values from homelab repo */ -}}
  sources:
    - repoURL: {{ $appRepoURL }}
      targetRevision: {{ (($app.repository).targetRevision) | default $root.Values.repository.targetRevision }}
      path: {{ $appPath }}
      helm:
        valueFiles:
          {{- if $app.helm }}
          {{- if $app.helm.valueFiles }}
          {{- if kindIs "slice" $app.helm.valueFiles }}
          {{- range $app.helm.valueFiles }}
          - $values/{{ . }}
          {{- end }}
          {{- else }}
          - $values/{{ $app.helm.valueFiles }}
          {{- end }}
          {{- else }}
          - $values/{{ $autoValueFileExternal }}
          {{- end }}
          {{- else }}
          - $values/{{ $autoValueFileExternal }}
          {{- end }}
        {{- if ($app.helm).values }}
        values: |
          {{- $app.helm.values | nindent 10 }}
        {{- end }}
        {{- if ($app.helm).parameters }}
        parameters:
          {{- range $app.helm.parameters }}
          - name: {{ .name }}
            value: {{ .value | quote }}
          {{- end }}
        {{- end }}
    - repoURL: {{ $root.Values.repository.url }}
      targetRevision: {{ $root.Values.repository.targetRevision }}
      ref: values
  {{- else }}
  {{/* Single source: chart and values from same repo */}}
  source:
    repoURL: {{ $appRepoURL }}
    targetRevision: {{ (($app.repository).targetRevision) | default $root.Values.repository.targetRevision }}
    path: {{ $appPath }}
    helm:
      valueFiles:
        {{- if $app.helm }}
        {{- if $app.helm.valueFiles }}
        {{- if kindIs "slice" $app.helm.valueFiles }}
        {{- range $app.helm.valueFiles }}
        - {{ . }}
        {{- end }}
        {{- else }}
        - {{ $app.helm.valueFiles }}
        {{- end }}
        {{- else }}
        - {{ $autoValueFile }}
        {{- end }}
        {{- else }}
        - {{ $autoValueFile }}
        {{- end }}
      {{- if ($app.helm).values }}
      values: |
        {{- $app.helm.values | nindent 8 }}
      {{- end }}
      {{- if ($app.helm).parameters }}
      parameters:
        {{- range $app.helm.parameters }}
        - name: {{ .name }}
          value: {{ .value | quote }}
        {{- end }}
      {{- end }}
  {{- end }}
  destination:
    server: {{ (($app.destination).server) | default $root.Values.destination.server }}
    namespace: {{ $appNamespace }}
  {{- include "app-of-apps.syncPolicy" (list
        (list $childDefaults.syncPolicy $layerChildDefaults.syncPolicy $app.syncPolicy)
        (list $childDefaults.additionalSyncOptions $layerChildDefaults.additionalSyncOptions $app.additionalSyncOptions)
      ) | nindent 2 }}
  {{- include "app-of-apps.ignoreDifferences" (list
        (list $app.ignoreDifferences $layerChildDefaults.ignoreDifferences $childDefaults.ignoreDifferences)
        (list $childDefaults.additionalIgnoreDifferences $layerChildDefaults.additionalIgnoreDifferences $app.additionalIgnoreDifferences)
      ) | nindent 2 }}
{{- end }}
