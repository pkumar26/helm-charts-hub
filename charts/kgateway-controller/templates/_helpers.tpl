{{/*
Chart name. Overridable via nameOverride value.
*/}}
{{- define "kgateway-controller.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name. Overridable via fullnameOverride value.
*/}}
{{- define "kgateway-controller.fullname" -}}
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
Selector labels used in spec.selector.matchLabels and metadata.labels for pods.
*/}}
{{- define "kgateway-controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kgateway-controller.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Image tag helper. Prepends "v" to Chart.AppVersion if no explicit tag is set.
This matches upstream kgateway image tagging convention.
*/}}
{{- define "kgateway-controller.imageTag" -}}
{{- .Values.image.tag | default (printf "v%s" .Chart.AppVersion) }}
{{- end }}

{{/*
Full image reference (registry/repository:tag).
*/}}
{{- define "kgateway-controller.image" -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.image.repository (include "kgateway-controller.imageTag" .) }}
{{- end }}

{{/*
Proxy image tag helper. Prepends "v" to Chart.AppVersion if no explicit proxy tag is set.
*/}}
{{- define "kgateway-controller.proxyImageTag" -}}
{{- .Values.controller.proxy.image.tag | default (printf "v%s" .Chart.AppVersion) }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "kgateway-controller.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- .Values.serviceAccount.name | default (include "kgateway-controller.fullname" .) }}
{{- else }}
{{- .Values.serviceAccount.name | default "default" }}
{{- end }}
{{- end }}
