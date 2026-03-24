{{/*
ArgoCD Application template for child applications

Defaults: path=kubernetes/apps/<name>, namespace=<name>, valueFiles=values/<env>.yaml
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
{{- $effectiveParentName := include "app-of-apps.effectiveName" (list $parentName $prefixNames $envName) -}}
{{- $effectiveAppName := include "app-of-apps.effectiveName" (list $app.name $prefixNames $envName) -}}
{{- $isDirectory := hasKey $app "directory" -}}
{{- $appPath := $app.path | default (printf "kubernetes/apps/%s" $app.name) -}}
{{- $appNamespace := $app.namespace | default $app.name -}}
{{- $appRepoURL := (($app.repository).url) | default $root.Values.repository.url -}}
{{- $isExternalRepo := and ($app.repository).url (ne $appRepoURL $root.Values.repository.url) (not $isDirectory) -}}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ $effectiveAppName }}
  namespace: argocd
  labels:
    parent: {{ $effectiveParentName }}
  {{- include "app-of-apps.mergedMap" (list "labels" $childDefaults.labels $parentChildDefaults.labels $app.labels) | nindent 2 }}
  {{- include "app-of-apps.mergedMap" (list "annotations" $childDefaults.annotations $parentChildDefaults.annotations $app.annotations) | nindent 2 }}
  {{- include "app-of-apps.firstNonEmptyList" (list "finalizers" $app.finalizers $parentChildDefaults.finalizers $childDefaults.finalizers) | nindent 2 }}
spec:
  project: {{ $effectiveParentName }}
{{- if $isExternalRepo }}
  sources:
    - repoURL: {{ $appRepoURL }}
      targetRevision: {{ (($app.repository).targetRevision) | default $root.Values.repository.targetRevision }}
      path: {{ $appPath }}
      helm:
        valueFiles:
          {{- $externalDefault := printf "kubernetes/apps/%s/values/%s.yaml" $app.name $envName -}}
          {{- include "app-of-apps.helmValueFiles" (list (($app.helm).valueFiles) $externalDefault "$values/") | nindent 10 }}
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
    {{- /* Helm source: render helm block if there's any content */ -}}
    {{- $hasValueFiles := and $app.helm (hasKey $app.helm "valueFiles") -}}
    {{- $emptyValueFiles := and $hasValueFiles (kindIs "slice" ($app.helm).valueFiles) (eq (len $app.helm.valueFiles) 0) -}}
    {{- $showValueFiles := not $emptyValueFiles -}}
    {{- $hasValues := and $app.helm $app.helm.values -}}
    {{- $hasParameters := and $app.helm $app.helm.parameters -}}
    {{- if or $showValueFiles $hasValues $hasParameters }}
    helm:
      {{- if $showValueFiles }}
      valueFiles:
        {{- $localDefault := printf "values/%s.yaml" $envName -}}
        {{- include "app-of-apps.helmValueFiles" (list (($app.helm).valueFiles) $localDefault "") | nindent 8 }}
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
