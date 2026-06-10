{{/*
Expand the name of the chart.
*/}}
{{- define "gateway-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "gateway-api.fullname" -}}
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
{{- define "gateway-api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "gateway-api.labels" -}}
helm.sh/chart: {{ include "gateway-api.chart" . }}
{{ include "gateway-api.selectorLabels" . }}
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
{{- define "gateway-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gateway-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Build service annotations for Azure AKS
*/}}
{{- define "gateway-api.serviceAnnotations" -}}
{{- if .Values.gateway.service.azure.healthProbe.enabled }}
service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: {{ .Values.gateway.service.azure.healthProbe.path | quote }}
service.beta.kubernetes.io/azure-load-balancer-health-probe-protocol: {{ .Values.gateway.service.azure.healthProbe.protocol | quote }}
service.beta.kubernetes.io/azure-load-balancer-health-probe-port: {{ .Values.gateway.service.azure.healthProbe.port | quote }}
{{- end }}
{{- if .Values.gateway.service.internal }}
{{- if .Values.gateway.service.azure }}
service.beta.kubernetes.io/azure-load-balancer-internal: "true"
{{- if .Values.gateway.service.azure.subnet }}
service.beta.kubernetes.io/azure-load-balancer-internal-subnet: {{ .Values.gateway.service.azure.subnet | quote }}
{{- end }}
{{- end }}
{{- if .Values.gateway.service.aws }}
service.beta.kubernetes.io/aws-load-balancer-scheme: internal
{{- end }}
{{- if .Values.gateway.service.gcp }}
networking.gke.io/load-balancer-type: "Internal"
{{- end }}
{{- end }}
{{- with .Values.serviceAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}
