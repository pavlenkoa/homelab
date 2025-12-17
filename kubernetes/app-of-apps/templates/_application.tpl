{{/*
ArgoCD Application template helper with global and project defaults
Supports external chart repositories with values from homelab repo using multiple sources

Features:
- Auto-generated valueFiles: values/{{ .Values.global.environmentName }}.yaml
- Project name auto-prefixing with environmentName (optional)
- Smart merge for ignoreDifferences (override) and additionalIgnoreDifferences (additive)
- Smart merge for syncOptions (override) and additionalSyncOptions (additive)
*/}}
{{- define "app-of-apps.application" -}}
{{- $root := index . 0 -}}
{{- $app := index . 1 -}}
{{- $projectName := index . 2 -}}
{{- $projectConfig := index . 3 -}}
{{- $global := $root.Values.global -}}
{{- /* Calculate effective project name - only prefix if prefixNames is true */}}
{{- $effectiveProjectName := $projectName -}}
{{- if $projectConfig.projectName }}
  {{- $effectiveProjectName = $projectConfig.projectName -}}
{{- else if and $global.environmentName $global.prefixNames }}
  {{- $effectiveProjectName = printf "%s-%s" $global.environmentName $projectName -}}
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
  project: {{ $effectiveProjectName }}
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
    namespace: {{ $app.namespace | default $projectConfig.namespace | default "default" }}
  syncPolicy:
    {{- $syncPolicy := mergeOverwrite (deepCopy $global.syncPolicy) ($projectConfig.syncPolicy | default dict) ($app.syncPolicy | default dict) }}
    {{- if $syncPolicy.automated }}
    automated:
      prune: {{ $syncPolicy.automated.prune }}
      selfHeal: {{ $syncPolicy.automated.selfHeal }}
    {{- end }}
    {{- /* Smart merge for syncOptions - support both override and additive */}}
    {{- if or $syncPolicy.syncOptions $global.additionalSyncOptions $projectConfig.additionalSyncOptions $app.additionalSyncOptions }}
    syncOptions:
      {{- /* Base syncOptions from merged syncPolicy */}}
      {{- range $syncPolicy.syncOptions }}
      - {{ . }}
      {{- end }}
      {{- /* Add additionalSyncOptions from all levels (additive) */}}
      {{- range $global.additionalSyncOptions }}
      - {{ . }}
      {{- end }}
      {{- range $projectConfig.additionalSyncOptions }}
      - {{ . }}
      {{- end }}
      {{- range $app.additionalSyncOptions }}
      - {{ . }}
      {{- end }}
    {{- end }}
    {{- if $syncPolicy.retry }}
    retry:
      limit: {{ $syncPolicy.retry.limit }}
      backoff:
        duration: {{ $syncPolicy.retry.backoff.duration }}
        factor: {{ $syncPolicy.retry.backoff.factor }}
        maxDuration: {{ $syncPolicy.retry.backoff.maxDuration }}
    {{- end }}
  {{- /* Smart merge ignoreDifferences with override and additive behavior */}}
  {{- $hasIgnoreDifferences := false }}
  {{- $baseIgnoreDifferences := list }}
  {{- /* Determine base ignoreDifferences (with override logic) */}}
  {{- if $app.ignoreDifferences }}
    {{- $baseIgnoreDifferences = $app.ignoreDifferences }}
    {{- $hasIgnoreDifferences = true }}
  {{- else if $projectConfig.ignoreDifferences }}
    {{- $baseIgnoreDifferences = $projectConfig.ignoreDifferences }}
    {{- $hasIgnoreDifferences = true }}
  {{- else if $global.ignoreDifferences }}
    {{- $baseIgnoreDifferences = $global.ignoreDifferences }}
    {{- $hasIgnoreDifferences = true }}
  {{- end }}
  {{- /* Check if any additionalIgnoreDifferences exist */}}
  {{- $hasAdditional := or $global.additionalIgnoreDifferences $projectConfig.additionalIgnoreDifferences $app.additionalIgnoreDifferences }}
  {{- if or $hasIgnoreDifferences $hasAdditional }}
  ignoreDifferences:
    {{- /* Output base ignoreDifferences (override behavior) */}}
    {{- range $baseIgnoreDifferences }}
    - {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- /* Merge all additionalIgnoreDifferences (additive behavior) */}}
    {{- range $global.additionalIgnoreDifferences }}
    - {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- range $projectConfig.additionalIgnoreDifferences }}
    - {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- range $app.additionalIgnoreDifferences }}
    - {{- toYaml . | nindent 6 }}
    {{- end }}
  {{- end }}
{{- end }}
