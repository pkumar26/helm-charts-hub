{{/*
ServiceAccount helper — renders a ServiceAccount resource.
Gated by serviceAccount.create. Name defaults to fullname.
Usage: {{ include "common-lib.serviceaccount" . }}
*/}}
{{- define "common-lib.serviceaccount" -}}
{{- if .Values.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Values.serviceAccount.name | default (include "common-lib.fullname" .) }}
  labels:
    {{- include "common-lib.labels" (dict "root" . "extraLabels" .Values.labels) | nindent 4 }}
  annotations:
    {{- include "common-lib.annotations" (dict "root" . "extraAnnotations" .Values.serviceAccount.annotations) | nindent 4 }}
{{- end }}
{{- end }}
