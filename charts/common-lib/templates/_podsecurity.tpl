{{/*
Pod security context helper — provides secure defaults.
Defaults: runAsNonRoot: true, readOnlyRootFilesystem: true, allowPrivilegeEscalation: false
Usage: {{ include "common-lib.podsecurity" . }}
*/}}
{{- define "common-lib.podsecurity" -}}
podSecurityContext:
  {{- toYaml .Values.podSecurityContext | nindent 2 }}
securityContext:
  {{- toYaml .Values.securityContext | nindent 2 }}
{{- end }}
