{{/*
Expand the name of the chart.
*/}}
{{- define "istiod.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "istiod.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "istiod.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "istiod.labels" -}}
helm.sh/chart: {{ include "istiod.chart" . }}
{{ include "istiod.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.labels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "istiod.selectorLabels" -}}
app.kubernetes.io/name: {{ include "istiod.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
FIPS image tag selector
Returns the appropriate image tag based on FIPS mode setting
*/}}
{{- define "istiod.imageTag" -}}
{{- if .Values.global.fips.enabled }}
{{- printf "%s-distroless" .Values.global.tag }}
{{- else }}
{{- .Values.global.tag }}
{{- end }}
{{- end }}

{{/*
FIPS image repository
Returns the appropriate image repository based on FIPS mode
*/}}
{{- define "istiod.imageRepo" -}}
{{- .Values.global.hub }}
{{- end }}

{{/*
Full image path with FIPS support
*/}}
{{- define "istiod.image" -}}
{{- printf "%s/pilot:%s" (include "istiod.imageRepo" .) (include "istiod.imageTag" .) }}
{{- end }}

{{/*
Check if FIPS mode is enabled
*/}}
{{- define "istiod.fipsEnabled" -}}
{{- if .Values.global.fips.enabled }}
{{- "true" }}
{{- else }}
{{- "false" }}
{{- end }}
{{- end }}

{{/*
FIPS environment variables
*/}}
{{- define "istiod.fipsEnv" -}}
{{- if .Values.global.fips.enabled }}
- name: GOFIPS
  value: "1"
- name: FIPS_MODE
  value: "true"
{{- end }}
{{- end }}

{{/*
Istio revision label
*/}}
{{- define "istiod.revisionLabel" -}}
{{- if .Values.revision }}
istio.io/rev: {{ .Values.revision }}
{{- else }}
istio.io/rev: default
{{- end }}
{{- end }}
