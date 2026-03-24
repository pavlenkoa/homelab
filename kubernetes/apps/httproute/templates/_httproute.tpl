{{- define "httproute.routes" -}}
{{- range .Values.httproute.routes }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ .name }}
spec:
  parentRefs:
    - name: {{ .gateway.name }}
      namespace: {{ .gateway.namespace }}
  hostnames:
    - {{ .hostname }}
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: {{ .service.name }}
          port: {{ .service.port }}
{{- end }}
{{- end -}}
