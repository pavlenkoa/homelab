{{/*
ArgoCD Application template helper for child applications

Features:
- Auto path: kubernetes/charts/<name>, Auto namespace: <name>
- Auto valueFiles: values/<environment>.yaml
- Name prefixing via layer's prefixNames setting

Merge order: childDefaults → layerConfig.childDefaults → app
*/}}
{{- define "app-of-apps.application" -}}
{{- $root := index . 0 -}}
{{- $app := index . 1 -}}
{{- $layerName := index . 2 -}}
{{- $layerConfig := index . 3 -}}
{{- $envName := $root.Values.environment -}}
{{- $childDefaults := $root.Values.childDefaults -}}
{{- $layerDefaults := $root.Values.layerDefaults -}}
{{- $layerChildDefaults := $layerConfig.childDefaults | default dict -}}
{{- $prefixNames := $layerConfig.prefixNames | default $layerDefaults.prefixNames -}}
{{- /* Calculate effective layer name (used as ArgoCD project) */ -}}
{{- $effectiveLayerName := $layerName -}}
{{- if $layerConfig.layerName }}
  {{- $effectiveLayerName = $layerConfig.layerName -}}
{{- else if $prefixNames }}
  {{- $effectiveLayerName = printf "%s-%s" $envName $layerName -}}
{{- end }}
{{- /* Calculate effective application name */ -}}
{{- $effectiveAppName := $app.name -}}
{{- if $prefixNames }}
  {{- $effectiveAppName = printf "%s-%s" $envName $app.name -}}
{{- end }}
{{- /* Smart defaults */ -}}
{{- $appPath := $app.path | default (printf "kubernetes/charts/%s" $app.name) -}}
{{- $appNamespace := $app.namespace | default $app.name -}}
{{- $appRepoURL := (($app.repository).url) | default $root.Values.repository.url -}}
{{- $useMultipleSources := and ($app.repository).url (ne $appRepoURL $root.Values.repository.url) -}}
{{- /* Auto-generate valueFiles if not specified */ -}}
{{- $autoValueFile := printf "values/%s.yaml" $envName -}}
{{- /* For external repos, use full path from homelab repo */ -}}
{{- $autoValueFileExternal := printf "kubernetes/charts/%s/values/%s.yaml" $app.name $envName -}}
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
