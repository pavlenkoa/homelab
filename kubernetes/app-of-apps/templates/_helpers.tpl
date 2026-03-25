{{/*
Shared helper functions for app-of-apps templates.
*/}}

{{/*
app-of-apps.effectiveName - Applies optional environment prefix
Arguments: list($name, $prefixNames, $envName)
*/}}
{{- define "app-of-apps.effectiveName" -}}
{{- $name := index . 0 -}}
{{- $prefixNames := index . 1 -}}
{{- $envName := index . 2 -}}
{{- ternary (printf "%s-%s" $envName $name) $name $prefixNames -}}
{{- end -}}

{{/*
app-of-apps.appProject - Renders an ArgoCD AppProject
Arguments: list($name, $description, $config, $root)
*/}}
{{- define "app-of-apps.appProject" -}}
{{- $name := index . 0 -}}
{{- $description := index . 1 -}}
{{- $config := index . 2 -}}
{{- $root := index . 3 -}}
{{- $defaults := $root.projectDefaults -}}
{{- $override := ($config).projectDefaults | default dict -}}
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: {{ $name }}
  namespace: argocd
  {{- include "app-of-apps.mergedMap" (list "annotations" ($defaults.annotations | default dict) ($override.annotations | default dict)) | nindent 2 }}
  {{- include "app-of-apps.firstNonEmptyList" (list "finalizers" ($override.finalizers) ($defaults.finalizers)) | nindent 2 }}
spec:
  description: {{ $description | quote }}
  sourceRepos:
    {{- range (($config).sourceRepos | default (list $root.repository.url)) }}
    - {{ . }}
    {{- end }}
  destinations:
    {{- if ($config).scopeDestinations -}}
    {{- $nsSet := dict "argocd" true -}}
    {{- range (($config).children | default list) -}}
      {{- if ne .enabled false -}}
        {{- $nsSet = set $nsSet (.namespace | default .name) true -}}
      {{- end -}}
    {{- end -}}
    {{- range $ns := keys $nsSet | sortAlpha }}
    - namespace: {{ $ns | quote }}
      server: {{ $root.destination.server }}
    {{- end }}
    {{- else -}}
    {{- range ($override.destinations | default $defaults.destinations) }}
    - namespace: {{ .namespace | quote }}
      server: {{ .server | default $root.destination.server }}
    {{- end }}
    {{- end }}
  clusterResourceWhitelist:
    {{- range ($override.clusterResourceWhitelist | default $defaults.clusterResourceWhitelist) }}
    - group: {{ .group | quote }}
      kind: {{ .kind | quote }}
    {{- end }}
  namespaceResourceWhitelist:
    {{- range ($override.namespaceResourceWhitelist | default $defaults.namespaceResourceWhitelist) }}
    - group: {{ .group | quote }}
      kind: {{ .kind | quote }}
    {{- end }}
  {{- if ($override.roles | default ($config).roles) }}
  roles:
    {{- toYaml ($override.roles | default ($config).roles) | nindent 4 }}
  {{- end }}
{{- end -}}

{{/*
app-of-apps.parentApplication - Renders a parent ArgoCD Application
Arguments: list($root, $parentName, $parentConfig)
*/}}
{{- define "app-of-apps.parentApplication" -}}
{{- $root := index . 0 -}}
{{- $parentName := index . 1 -}}
{{- $parentConfig := index . 2 -}}
{{- $parentDefaults := $root.Values.parentDefaults -}}
{{- $envName := $root.Values.environment -}}
{{- $prefixNames := $parentConfig.prefixNames | default $parentDefaults.prefixNames -}}
{{- $effectiveName := include "app-of-apps.effectiveName" (list $parentName $prefixNames $envName) -}}
{{- $projectName := include "app-of-apps.effectiveName" (list "parents" $prefixNames $envName) -}}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ $effectiveName }}
  namespace: argocd
  labels:
    environment: {{ $envName }}
  {{- include "app-of-apps.mergedMap" (list "labels" $parentDefaults.labels $parentConfig.labels) | nindent 2 }}
  {{- include "app-of-apps.mergedMap" (list "annotations" $parentDefaults.annotations $parentConfig.annotations) | nindent 2 }}
  {{- include "app-of-apps.firstNonEmptyList" (list "finalizers" $parentConfig.finalizers $parentDefaults.finalizers) | nindent 2 }}
spec:
  project: {{ $projectName }}
  source:
    repoURL: {{ ($parentConfig.repository).url | default $root.Values.repository.url }}
    targetRevision: {{ ($parentConfig.repository).targetRevision | default $root.Values.repository.targetRevision }}
    path: kubernetes/app-of-apps
    helm:
      parameters:
        - name: renderParent
          value: {{ $parentName }}
  destination:
    server: {{ (($parentConfig.destination).server) | default (($parentDefaults.destination).server) | default $root.Values.destination.server }}
    namespace: argocd
  {{- include "app-of-apps.syncPolicy" (list
        (list $parentDefaults.syncPolicy $parentConfig.syncPolicy)
        (list $parentDefaults.additionalSyncOptions $parentConfig.additionalSyncOptions)
      ) | nindent 2 }}
  {{- include "app-of-apps.ignoreDifferences" (list
        (list $parentConfig.ignoreDifferences $parentDefaults.ignoreDifferences)
        (list $parentDefaults.additionalIgnoreDifferences $parentConfig.additionalIgnoreDifferences)
      ) | nindent 2 }}
{{- end -}}

{{/*
app-of-apps.syncPolicy - Renders syncPolicy block
Arguments: list($configs, $additionalSyncOptionsList)
*/}}
{{- define "app-of-apps.syncPolicy" -}}
{{- $configs := index . 0 -}}
{{- $additionalSyncOptionsList := index . 1 -}}
{{- $merged := dict -}}
{{- range $configs -}}
  {{- if . -}}
    {{- $merged = mergeOverwrite $merged (deepCopy .) -}}
  {{- end -}}
{{- end -}}
syncPolicy:
  {{- if $merged.automated }}
  automated:
    {{- if $merged.automated.prune }}
    prune: true
    {{- end }}
    {{- if $merged.automated.selfHeal }}
    selfHeal: true
    {{- end }}
  {{- end }}
  {{- $allSyncOptions := ($merged.syncOptions | default list) -}}
  {{- range $additionalSyncOptionsList -}}
    {{- $allSyncOptions = concat $allSyncOptions (. | default list) -}}
  {{- end -}}
  {{- if $allSyncOptions }}
  syncOptions:
    {{- range $allSyncOptions }}
    - {{ . }}
    {{- end }}
  {{- end }}
  {{- if $merged.retry }}
  retry:
    limit: {{ $merged.retry.limit }}
    backoff:
      duration: {{ $merged.retry.backoff.duration }}
      factor: {{ $merged.retry.backoff.factor }}
      maxDuration: {{ $merged.retry.backoff.maxDuration }}
  {{- end }}
{{- end -}}

{{/*
app-of-apps.ignoreDifferences - Renders ignoreDifferences block
Arguments: list($baseConfigs, $additionalConfigs)
  $baseConfigs - first non-empty wins (override)
  $additionalConfigs - all merged (additive)
*/}}
{{- define "app-of-apps.ignoreDifferences" -}}
{{- $base := list -}}
{{- range (index . 0) -}}
  {{- if and (not $base) . -}}
    {{- $base = . -}}
  {{- end -}}
{{- end -}}
{{- $additional := list -}}
{{- range (index . 1) -}}
  {{- $additional = concat $additional (. | default list) -}}
{{- end -}}
{{- if or $base $additional -}}
ignoreDifferences:
{{- range $base }}
  - {{- toYaml . | nindent 4 }}
{{- end }}
{{- range $additional }}
  - {{- toYaml . | nindent 4 }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
app-of-apps.mergedMap - Merges maps and renders as a named YAML block
Arguments: list($blockName, $maps...)
Replaces separate annotations/labels helpers.
*/}}
{{- define "app-of-apps.mergedMap" -}}
{{- $blockName := index . 0 -}}
{{- $merged := dict -}}
{{- range (slice . 1) -}}
  {{- if . -}}
    {{- $merged = mergeOverwrite $merged . -}}
  {{- end -}}
{{- end -}}
{{- if $merged -}}
{{ $blockName }}:
{{- range $key := keys $merged | sortAlpha }}
  {{ $key }}: {{ index $merged $key | quote }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
app-of-apps.firstNonEmptyList - Renders first non-empty list as a named YAML block
Arguments: list($blockName, $lists...)
Replaces separate finalizers helper.
*/}}
{{- define "app-of-apps.firstNonEmptyList" -}}
{{- $blockName := index . 0 -}}
{{- $result := list -}}
{{- range (slice . 1) -}}
  {{- if and (not $result) . -}}
    {{- $result = . -}}
  {{- end -}}
{{- end -}}
{{- if $result -}}
{{ $blockName }}:
{{- range $result }}
  - {{ . }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
app-of-apps.helmValueFiles - Renders valueFiles list
Arguments: list($valueFiles, $defaultFile, $prefix)
  $valueFiles - explicit valueFiles from app config (may be nil, empty list, string, or list)
  $defaultFile - auto-generated default value file path
  $prefix - prefix for each entry (e.g. "$values/" for multi-source, "" for single-source)
*/}}
{{- define "app-of-apps.helmValueFiles" -}}
{{- $valueFiles := index . 0 -}}
{{- $defaultFile := index . 1 -}}
{{- $prefix := index . 2 -}}
{{- if kindIs "slice" $valueFiles -}}
  {{- range $valueFiles }}
- {{ $prefix }}{{ . }}
  {{- end }}
{{- else if $valueFiles -}}
- {{ $prefix }}{{ $valueFiles }}
{{- else if $defaultFile -}}
- {{ $prefix }}{{ $defaultFile }}
{{- end -}}
{{- end -}}
