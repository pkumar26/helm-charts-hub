{{/*
Secret helper — renders a Secret resource with base64 encoding.
Usage: {{ include "common-lib.secrets" (dict "root" . "data" .Values.secretData) }}
*/}}
{{- define "common-lib.secrets" -}}
{{- $root := .root -}}
{{- if .data }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "common-lib.fullname" $root }}
  labels:
    {{- include "common-lib.labels" (dict "root" $root "extraLabels" $root.Values.labels) | nindent 4 }}
  annotations:
    {{- include "common-lib.annotations" (dict "root" $root "extraAnnotations" $root.Values.annotations) | nindent 4 }}
type: Opaque
data:
  {{- range $key, $value := .data }}
  {{ $key }}: {{ $value | b64enc | quote }}
  {{- end }}
{{- end }}
{{- end }}
