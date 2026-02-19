{{/*
ConfigMap helper — renders a ConfigMap resource.
Usage: {{ include "common-lib.configmap" (dict "root" . "data" .Values.configData) }}
*/}}
{{- define "common-lib.configmap" -}}
{{- $root := .root -}}
{{- if .data }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "common-lib.fullname" $root }}
  labels:
    {{- include "common-lib.labels" (dict "root" $root "extraLabels" $root.Values.labels) | nindent 4 }}
  annotations:
    {{- include "common-lib.annotations" (dict "root" $root "extraAnnotations" $root.Values.annotations) | nindent 4 }}
data:
  {{- range $key, $value := .data }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
{{- end }}
{{- end }}
