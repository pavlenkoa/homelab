{{- define "httproute.routes" -}}
{{- range .Values.httproute.routes }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ .name }}
spec:
  parentRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: {{ .gateway.name }}
      namespace: {{ .gateway.namespace }}
  hostnames:
    - {{ .hostname }}
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - group: ""
          kind: Service
          name: {{ .service.name }}
          port: {{ .service.port }}
          weight: 1
{{- end }}
{{- end -}}
