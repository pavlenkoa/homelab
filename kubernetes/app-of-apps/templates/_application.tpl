{{/*
ArgoCD Application template helper for child applications

Features:
- Auto path: kubernetes/charts/<name> (helm) or kubernetes/manifests/<name> (directory)
- Auto namespace: <name>
- Auto valueFiles: values/<environment>.yaml (helm only)
- Name prefixing via layer's prefixNames setting
- Directory source support for plain manifests

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
{{- $effectiveLayerName := $layerName -}}
{{- if $prefixNames }}
  {{- $effectiveLayerName = printf "%s-%s" $envName $layerName -}}
{{- end }}
{{- /* Calculate effective application name */ -}}
{{- $effectiveAppName := $app.name -}}
{{- if $prefixNames }}
  {{- $effectiveAppName = printf "%s-%s" $envName $app.name -}}
{{- end }}
{{- /* Determine source type: directory (plain manifests) or helm (default) */ -}}
{{- $isDirectory := hasKey $app "directory" -}}
{{- /* Smart defaults - path depends on source type */ -}}
{{- $defaultPath := ternary (printf "kubernetes/manifests/%s" $app.name) (printf "kubernetes/charts/%s" $app.name) $isDirectory -}}
{{- $appPath := $app.path | default $defaultPath -}}
{{- $appNamespace := $app.namespace | default $app.name -}}
{{- $appRepoURL := (($app.repository).url) | default $root.Values.repository.url -}}
{{- $useMultipleSources := and ($app.repository).url (ne $appRepoURL $root.Values.repository.url) (not $isDirectory) -}}
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
  source:
    repoURL: {{ $appRepoURL }}
    targetRevision: {{ (($app.repository).targetRevision) | default $root.Values.repository.targetRevision }}
    path: {{ $appPath }}
{{- if $isDirectory }}
{{- with $app.directory }}
{{- if or .recurse .include .exclude }}
    directory:
      {{- if .recurse }}
      recurse: {{ .recurse }}
      {{- end }}
      {{- if .include }}
      include: {{ .include | quote }}
      {{- end }}
      {{- if .exclude }}
      exclude: {{ .exclude | quote }}
      {{- end }}
{{- end }}
{{- end }}
{{- else }}
    helm:
      {{- $hasValueFiles := false }}
      {{- if $app.helm }}
      {{- if $app.helm.valueFiles }}
      {{- if kindIs "slice" $app.helm.valueFiles }}
      {{- if gt (len $app.helm.valueFiles) 0 }}
      {{- $hasValueFiles = true }}
      {{- end }}
      {{- else }}
      {{- $hasValueFiles = true }}
      {{- end }}
      {{- end }}
      {{- end }}
      {{- if or $hasValueFiles (not $app.helm) (not (hasKey ($app.helm | default dict) "valueFiles")) }}
      valueFiles:
        {{- if $hasValueFiles }}
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
