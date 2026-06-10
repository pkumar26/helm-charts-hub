{{/*
Expand the name of the chart.
*/}}
{{- define "istio-gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "istio-gateway.fullname" -}}
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
{{- define "istio-gateway.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "istio-gateway.labels" -}}
helm.sh/chart: {{ include "istio-gateway.chart" . }}
{{ include "istio-gateway.selectorLabels" . }}
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
{{- define "istio-gateway.selectorLabels" -}}
app.kubernetes.io/name: {{ include "istio-gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Gateway service account name
*/}}
{{- define "istio-gateway.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "istio-gateway.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Determine the image tag to use, appending -distroless if FIPS is enabled
*/}}
{{- define "istio-gateway.imageTag" -}}
{{- if .Values.global.fips.enabled }}
{{- printf "%s-distroless" .Values.global.tag }}
{{- else }}
{{- .Values.global.tag }}
{{- end }}
{{- end }}

{{/*
Check if FIPS mode is enabled
*/}}
{{- define "istio-gateway.fipsEnabled" -}}
{{- if .Values.global.fips.enabled }}
true
{{- else }}
false
{{- end }}
{{- end }}

{{/*
Environment variables for FIPS mode
*/}}
{{- define "istio-gateway.fipsEnv" -}}
{{- if .Values.global.fips.enabled }}
- name: GOFIPS
  value: "1"
- name: FIPS_MODE
  value: "true"
{{- end }}
{{- end }}

{{/*
Gateway namespace - defaults to Release.Namespace
*/}}
{{- define "istio-gateway.namespace" -}}
{{- default .Release.Namespace .Values.global.istioNamespace }}
{{- end }}
