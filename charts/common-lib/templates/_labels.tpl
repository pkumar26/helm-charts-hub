{{/*
Common labels — 6 base labels + optional extraLabels merge.
Usage: {{ include "common-lib.labels" (dict "root" .) }}
Usage with extras: {{ include "common-lib.labels" (dict "root" . "extraLabels" .Values.labels) }}
*/}}
{{- define "common-lib.labels" -}}
{{- $root := .root -}}
app.kubernetes.io/name: {{ $root.Chart.Name }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
app.kubernetes.io/version: {{ $root.Chart.AppVersion | default "0.0.0" | quote }}
app.kubernetes.io/managed-by: {{ $root.Release.Service }}
app.kubernetes.io/part-of: helm-charts-hub
helm.sh/chart: {{ include "common-lib.chart" $root }}
{{- if .extraLabels }}
{{ toYaml .extraLabels }}
{{- end }}
{{- end }}

{{/*
Selector labels — immutable subset used by Deployments and Services.
Usage: {{ include "common-lib.selectorLabels" . }}
*/}}
{{- define "common-lib.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
