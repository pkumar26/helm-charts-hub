{{/*
Service helper — renders a complete Service resource.
Only rendered when workloadType is "deployment" (workers and CronJobs have no Service).
Usage: {{ include "common-lib.service" (dict "root" .) }}
*/}}
{{- define "common-lib.service" -}}
{{- $root := .root -}}
{{- if eq $root.Values.workloadType "deployment" }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "common-lib.fullname" $root }}
  labels:
    {{- include "common-lib.labels" (dict "root" $root "extraLabels" $root.Values.labels) | nindent 4 }}
  annotations:
    {{- include "common-lib.annotations" (dict "root" $root "extraAnnotations" $root.Values.annotations) | nindent 4 }}
spec:
  type: {{ $root.Values.service.type }}
  ports:
    - port: {{ $root.Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "common-lib.selectorLabels" $root | nindent 4 }}
{{- end }}
{{- end }}
