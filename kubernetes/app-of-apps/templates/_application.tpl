{{/*
ArgoCD Application template helper for child applications
Supports external chart repositories with values from homelab repo using multiple sources

Features:
- Auto-generated valueFiles: values/{{ .Values.global.environmentName }}.yaml
- Layer name auto-prefixing with environmentName (optional)
- Uses shared helpers for syncPolicy, ignoreDifferences, annotations, finalizers
*/}}
{{- define "app-of-apps.application" -}}
{{- $root := index . 0 -}}
{{- $app := index . 1 -}}
{{- $layerName := index . 2 -}}
{{- $layerConfig := index . 3 -}}
{{- $global := $root.Values.global -}}
{{- /* Calculate effective layer name (used as ArgoCD project) - only prefix if prefixNames is true */}}
{{- $effectiveLayerName := $layerName -}}
{{- if $layerConfig.layerName }}
  {{- $effectiveLayerName = $layerConfig.layerName -}}
{{- else if and $global.environmentName $global.prefixNames }}
  {{- $effectiveLayerName = printf "%s-%s" $global.environmentName $layerName -}}
{{- end }}
{{- /* Calculate effective application name - only prefix if prefixNames is true */}}
{{- $effectiveAppName := $app.name -}}
{{- if and $global.environmentName $global.prefixNames }}
  {{- $effectiveAppName = printf "%s-%s" $global.environmentName $app.name -}}
{{- end }}
{{- $appRepoURL := (($app.repository).url) | default $global.repository.url -}}
{{- $useMultipleSources := and ($app.repository).url (ne $appRepoURL $global.repository.url) -}}
{{- /* Auto-generate valueFiles if not specified */}}
{{- $autoValueFile := printf "values/%s.yaml" $global.environmentName -}}
{{- /* For external repos, use full path from homelab repo */}}
{{- $autoValueFileExternal := printf "kubernetes/charts/%s/values/%s.yaml" $app.name $global.environmentName -}}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ $effectiveAppName }}
  namespace: argocd
  {{- include "app-of-apps.annotations" (list $global.annotations $app.annotations) | nindent 2 }}
  {{- include "app-of-apps.finalizers" (list $app.finalizers $global.finalizers) | nindent 2 }}
spec:
  project: {{ $effectiveLayerName }}
  {{- if $useMultipleSources }}
  {{- /* Multiple sources: chart from external repo, values from homelab repo */}}
  sources:
    - repoURL: {{ $appRepoURL }}
      targetRevision: {{ (($app.repository).targetRevision) | default $global.repository.targetRevision }}
      path: {{ $app.path }}
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
    - repoURL: {{ $global.repository.url }}
      targetRevision: {{ $global.repository.targetRevision }}
      ref: values
  {{- else }}
  {{- /* Single source: chart and values from same repo */}}
  source:
    repoURL: {{ $appRepoURL }}
    targetRevision: {{ (($app.repository).targetRevision) | default $global.repository.targetRevision }}
    path: {{ $app.path }}
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
    server: {{ (($app.destination).server) | default $global.destination.server }}
    namespace: {{ $app.namespace | default $layerConfig.namespace | default "default" }}
  {{- include "app-of-apps.syncPolicy" (list
        (list $global.syncPolicy $layerConfig.syncPolicy $app.syncPolicy)
        (list $global.additionalSyncOptions $layerConfig.additionalSyncOptions $app.additionalSyncOptions)
      ) | nindent 2 }}
  {{- include "app-of-apps.ignoreDifferences" (list
        (list $app.ignoreDifferences $layerConfig.ignoreDifferences $global.ignoreDifferences)
        (list $global.additionalIgnoreDifferences $layerConfig.additionalIgnoreDifferences $app.additionalIgnoreDifferences)
      ) | nindent 2 }}
{{- end }}
