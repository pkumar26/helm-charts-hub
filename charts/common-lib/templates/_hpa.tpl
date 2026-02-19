{{/*
HPA helper — renders a HorizontalPodAutoscaler resource (autoscaling/v2).
Gated by autoscaling.enabled. Produces no output when disabled.
Usage: {{ include "common-lib.hpa" (dict "root" .) }}
*/}}
{{- define "common-lib.hpa" -}}
{{- $root := .root -}}
{{- if $root.Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "common-lib.fullname" $root }}
  labels:
    {{- include "common-lib.labels" (dict "root" $root "extraLabels" $root.Values.labels) | nindent 4 }}
  annotations:
    {{- include "common-lib.annotations" (dict "root" $root "extraAnnotations" $root.Values.annotations) | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "common-lib.fullname" $root }}
  minReplicas: {{ $root.Values.autoscaling.minReplicas }}
  maxReplicas: {{ $root.Values.autoscaling.maxReplicas }}
  metrics:
    {{- if $root.Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ $root.Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if $root.Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ $root.Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
{{- end }}
