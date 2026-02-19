{{/*
Common annotations — 2 base annotations + optional extraAnnotations merge.
Supports configurable global.annotationPrefix for ownership annotations.
Usage: {{ include "common-lib.annotations" (dict "root" .) }}
Usage with extras: {{ include "common-lib.annotations" (dict "root" . "extraAnnotations" .Values.annotations) }}
*/}}
{{- define "common-lib.annotations" -}}
{{- $root := .root -}}
meta.helm.sh/release-name: {{ $root.Release.Name }}
meta.helm.sh/release-namespace: {{ $root.Release.Namespace }}
{{- if .extraAnnotations }}
{{ toYaml .extraAnnotations }}
{{- end }}
{{- end }}
