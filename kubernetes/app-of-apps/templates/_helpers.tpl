{{/*
Shared helper functions for app-of-apps templates.
Used by parents.yaml, children.yaml, and _application.tpl.
*/}}

{{/*
app-of-apps.appProject - Renders an ArgoCD AppProject
Arguments: list($name, $description, $config, $root)
  $name - project name
  $description - project description
  $config - parent config (for sourceRepos, projectDefaults override)
  $root - root Values object (for projectDefaults, repository, destination)
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
  {{- $annotations := mergeOverwrite (deepCopy ($defaults.annotations | default dict)) ($override.annotations | default dict) -}}
  {{- if $annotations }}
  annotations:
    {{- range $key, $value := $annotations }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
  {{- end }}
  {{- $finalizers := ($override.finalizers | default $defaults.finalizers) -}}
  {{- if $finalizers }}
  finalizers:
    {{- range $finalizers }}
    - {{ . }}
    {{- end }}
  {{- end }}
spec:
  description: {{ $description | quote }}
  sourceRepos:
    {{- $defaultRepos := list $root.repository.url -}}
    {{- range (($config).sourceRepos | default $defaultRepos) }}
    - {{ . }}
    {{- end }}
  destinations:
    {{- $destinations := ($override.destinations | default $defaults.destinations) -}}
    {{- range $destinations }}
    - namespace: {{ .namespace | quote }}
      server: {{ .server | default $root.destination.server }}
    {{- end }}
  clusterResourceWhitelist:
    {{- $clusterWhitelist := ($override.clusterResourceWhitelist | default $defaults.clusterResourceWhitelist) -}}
    {{- range $clusterWhitelist }}
    - group: {{ .group | quote }}
      kind: {{ .kind | quote }}
    {{- end }}
  namespaceResourceWhitelist:
    {{- $nsWhitelist := ($override.namespaceResourceWhitelist | default $defaults.namespaceResourceWhitelist) -}}
    {{- range $nsWhitelist }}
    - group: {{ .group | quote }}
      kind: {{ .kind | quote }}
    {{- end }}
  {{- $roles := ($override.roles | default ($config).roles) -}}
  {{- if $roles }}
  roles:
    {{- toYaml $roles | nindent 4 }}
  {{- else }}
  roles: []
  {{- end }}
{{- end -}}

{{/*
app-of-apps.syncPolicy - Renders syncPolicy block
Arguments: list($configs, $additionalSyncOptionsList)
  $configs - list of syncPolicy objects to merge (later overrides earlier)
  $additionalSyncOptionsList - list of additionalSyncOptions arrays (all merged)
*/}}
{{- define "app-of-apps.syncPolicy" -}}
{{- $args := . -}}
{{- $configs := index $args 0 -}}
{{- $additionalSyncOptionsList := index $args 1 -}}
{{- /* Merge all syncPolicy configs */ -}}
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
  {{- /* Collect all syncOptions */ -}}
  {{- $allSyncOptions := list -}}
  {{- range ($merged.syncOptions | default list) -}}
    {{- $allSyncOptions = append $allSyncOptions . -}}
  {{- end -}}
  {{- range $additionalSyncOptionsList -}}
    {{- range (. | default list) -}}
      {{- $allSyncOptions = append $allSyncOptions . -}}
    {{- end -}}
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
  $baseConfigs - list of ignoreDifferences arrays (first non-empty wins - override)
  $additionalConfigs - list of additionalIgnoreDifferences arrays (all merged - additive)
*/}}
{{- define "app-of-apps.ignoreDifferences" -}}
{{- $baseConfigs := index . 0 -}}
{{- $additionalConfigs := index . 1 -}}
{{- /* Find first non-empty base (override behavior) */ -}}
{{- $base := list -}}
{{- range $baseConfigs -}}
  {{- if and (not $base) . -}}
    {{- $base = . -}}
  {{- end -}}
{{- end -}}
{{- /* Collect all additional (additive behavior) */ -}}
{{- $additional := list -}}
{{- range $additionalConfigs -}}
  {{- range (. | default list) -}}
    {{- $additional = append $additional . -}}
  {{- end -}}
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
app-of-apps.annotations - Renders annotations block
Arguments: list($annotationMaps...)
  Merges all annotation maps, later ones override earlier
*/}}
{{- define "app-of-apps.annotations" -}}
{{- $merged := dict -}}
{{- range . -}}
  {{- if . -}}
    {{- $merged = mergeOverwrite $merged . -}}
  {{- end -}}
{{- end -}}
{{- if $merged -}}
annotations:
{{- range $key, $value := $merged }}
  {{ $key }}: {{ $value | quote }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
app-of-apps.labels - Renders labels
Arguments: list($labelMaps...)
  Merges all label maps, later ones override earlier
*/}}
{{- define "app-of-apps.labels" -}}
{{- $merged := dict -}}
{{- range . -}}
  {{- if . -}}
    {{- $merged = mergeOverwrite $merged . -}}
  {{- end -}}
{{- end -}}
{{- range $key, $value := $merged }}
  {{ $key }}: {{ $value | quote }}
{{- end }}
{{- end -}}

{{/*
app-of-apps.finalizers - Renders finalizers list
Arguments: list($finalizerLists...)
  Uses first non-empty list (override behavior)
*/}}
{{- define "app-of-apps.finalizers" -}}
{{- $finalizers := list -}}
{{- range . -}}
  {{- if and (not $finalizers) . -}}
    {{- $finalizers = . -}}
  {{- end -}}
{{- end -}}
{{- if $finalizers -}}
finalizers:
{{- range $finalizers }}
  - {{ . }}
{{- end }}
{{- end -}}
{{- end -}}
