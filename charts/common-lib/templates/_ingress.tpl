{{/*
Ingress helper — renders a complete Ingress resource (networking.k8s.io/v1).
Gated by ingress.enabled. Produces no output when disabled.
Usage: {{ include "common-lib.ingress" (dict "root" .) }}
*/}}
{{- define "common-lib.ingress" -}}
{{- $root := .root -}}
{{- if $root.Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "common-lib.fullname" $root }}
  labels:
    {{- include "common-lib.labels" (dict "root" $root "extraLabels" $root.Values.labels) | nindent 4 }}
  annotations:
    {{- include "common-lib.annotations" (dict "root" $root "extraAnnotations" (merge (default (dict) $root.Values.ingress.annotations) (default (dict) $root.Values.annotations))) | nindent 4 }}
spec:
  {{- if $root.Values.ingress.className }}
  ingressClassName: {{ $root.Values.ingress.className }}
  {{- end }}
  {{- if $root.Values.ingress.tls }}
  tls:
    {{- range $root.Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range $root.Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType | default "Prefix" }}
            backend:
              service:
                name: {{ include "common-lib.fullname" $root }}
                port:
                  number: {{ $root.Values.service.port }}
          {{- end }}
    {{- end }}
{{- end }}
{{- end }}
