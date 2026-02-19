{{/*
Deployment helper — renders a complete Deployment resource.
Includes workloadType guard, image validation, probes, security context,
resource limits, extraEnv, extraVolumes, and extraVolumeMounts.
Usage: {{ include "common-lib.deployment" (dict "root" .) }}
*/}}
{{- define "common-lib.deployment" -}}
{{- $root := .root -}}
{{- if not (has $root.Values.workloadType (list "deployment")) }}
{{- fail (printf "workloadType must be one of: deployment. Got: %s" $root.Values.workloadType) }}
{{- end }}
{{- $_ := required "image.repository is required" $root.Values.image.repository }}
{{- if not $root.Values.image.tag }}
{{- fail "image.tag must not be empty" }}
{{- end }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common-lib.fullname" $root }}
  labels:
    {{- include "common-lib.labels" (dict "root" $root "extraLabels" $root.Values.labels) | nindent 4 }}
  annotations:
    {{- include "common-lib.annotations" (dict "root" $root "extraAnnotations" $root.Values.annotations) | nindent 4 }}
spec:
  {{- if not $root.Values.autoscaling.enabled }}
  replicas: {{ $root.Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "common-lib.selectorLabels" $root | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "common-lib.selectorLabels" $root | nindent 8 }}
        {{- with $root.Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with $root.Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    spec:
      {{- if $root.Values.serviceAccount.create }}
      serviceAccountName: {{ $root.Values.serviceAccount.name | default (include "common-lib.fullname" $root) }}
      {{- end }}
      securityContext:
        {{- toYaml $root.Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ $root.Chart.Name }}
          image: "{{ $root.Values.image.repository }}:{{ $root.Values.image.tag }}"
          imagePullPolicy: {{ $root.Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ $root.Values.service.port }}
              protocol: TCP
          {{- with $root.Values.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $root.Values.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml $root.Values.resources | nindent 12 }}
          securityContext:
            {{- toYaml $root.Values.securityContext | nindent 12 }}
          {{- with $root.Values.extraEnv }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $root.Values.extraVolumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with $root.Values.extraVolumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $root.Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $root.Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $root.Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
