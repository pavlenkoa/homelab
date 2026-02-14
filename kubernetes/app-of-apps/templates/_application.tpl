{{/*
ArgoCD Application template helper for child applications

Features:
- Auto path: kubernetes/charts/<name> (helm) or kubernetes/manifests/<name> (directory)
- Auto namespace: <name>
- Auto valueFiles: values/<environment>.yaml (helm only)
- Name prefixing via parent's prefixNames setting
- Directory source support for plain manifests

Merge order: childDefaults → parentConfig.childDefaults → app
*/}}
{{- define "app-of-apps.application" -}}
{{- $root := index . 0 -}}
{{- $app := index . 1 -}}
{{- $parentName := index . 2 -}}
{{- $parentConfig := index . 3 -}}
{{- $envName := $root.Values.environment -}}
{{- $childDefaults := $root.Values.childDefaults -}}
{{- $parentDefaults := $root.Values.parentDefaults -}}
{{- $parentChildDefaults := $parentConfig.childDefaults | default dict -}}
{{- $prefixNames := $parentConfig.prefixNames | default $parentDefaults.prefixNames -}}
{{- $effectiveParentName := $parentName -}}
{{- if $prefixNames }}
  {{- $effectiveParentName = printf "%s-%s" $envName $parentName -}}
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
  labels:
    parent: {{ $effectiveParentName }}
  {{- include "app-of-apps.labels" (list $childDefaults.labels $parentChildDefaults.labels $app.labels) | nindent 2 }}
  {{- include "app-of-apps.annotations" (list $childDefaults.annotations $parentChildDefaults.annotations $app.annotations) | nindent 2 }}
  {{- include "app-of-apps.finalizers" (list $app.finalizers $parentChildDefaults.finalizers $childDefaults.finalizers) | nindent 2 }}
spec:
  project: {{ $effectiveParentName }}
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
    targetRevision: {{ (($app.repository).targetRevision) | default (($root.Values.chartsRepository).targetRevision) | default $root.Values.repository.targetRevision }}
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
    {{- /* Determine what helm options we have */ -}}
    {{- $hasExplicitValueFiles := false -}}
    {{- $emptyValueFiles := false -}}
    {{- if $app.helm -}}
      {{- if hasKey $app.helm "valueFiles" -}}
        {{- if kindIs "slice" $app.helm.valueFiles -}}
          {{- if gt (len $app.helm.valueFiles) 0 -}}
            {{- $hasExplicitValueFiles = true -}}
          {{- else -}}
            {{- $emptyValueFiles = true -}}
          {{- end -}}
        {{- else -}}
          {{- $hasExplicitValueFiles = true -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
    {{- $hasValues := and $app.helm $app.helm.values -}}
    {{- $hasParameters := and $app.helm $app.helm.parameters -}}
    {{- $useDefaultValueFile := and (not $hasExplicitValueFiles) (not $emptyValueFiles) -}}
    {{- $hasHelmContent := or $hasExplicitValueFiles $useDefaultValueFile $hasValues $hasParameters -}}
    {{- if $hasHelmContent }}
    helm:
      {{- if or $hasExplicitValueFiles $useDefaultValueFile }}
      valueFiles:
        {{- if $hasExplicitValueFiles }}
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
      {{- if $hasValues }}
      values: |
        {{- $app.helm.values | nindent 8 }}
      {{- end }}
      {{- if $hasParameters }}
      parameters:
        {{- range $app.helm.parameters }}
        - name: {{ .name }}
          value: {{ .value | quote }}
        {{- end }}
      {{- end }}
    {{- end }}
{{- end }}
{{- end }}
  destination:
    server: {{ (($app.destination).server) | default (($parentChildDefaults.destination).server) | default (($childDefaults.destination).server) | default $root.Values.destination.server }}
    namespace: {{ $appNamespace }}
  {{- include "app-of-apps.syncPolicy" (list
        (list $childDefaults.syncPolicy $parentChildDefaults.syncPolicy $app.syncPolicy)
        (list $childDefaults.additionalSyncOptions $parentChildDefaults.additionalSyncOptions $app.additionalSyncOptions)
      ) | nindent 2 }}
  {{- include "app-of-apps.ignoreDifferences" (list
        (list $app.ignoreDifferences $parentChildDefaults.ignoreDifferences $childDefaults.ignoreDifferences)
        (list $childDefaults.additionalIgnoreDifferences $parentChildDefaults.additionalIgnoreDifferences $app.additionalIgnoreDifferences)
      ) | nindent 2 }}
{{- end }}
