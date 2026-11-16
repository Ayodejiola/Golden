{{/* Name helpers */}}
{{- define "gs.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "gs.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "gs.component" -}}
{{- default (include "gs.fullname" .) .Values.component -}}
{{- end -}}

{{- define "gs.serviceAccountName" -}}
{{- default (include "gs.fullname" .) .Values.serviceAccount.name -}}
{{- end -}}

{{/* Selector labels: immutable, keep minimal */}}
{{- define "gs.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gs.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Standard labels: Kubernetes recommended + Harborline ownership/governance labels (Kyverno require-labels) */}}
{{- define "gs.labels" -}}
{{ include "gs.selectorLabels" . }}
app.kubernetes.io/version: {{ default .Chart.AppVersion .Values.image.tag | quote }}
app.kubernetes.io/part-of: {{ .Values.system }}
app.kubernetes.io/component: {{ include "gs.component" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
harborline.io/team: {{ required "team is required" .Values.team }}
harborline.io/system: {{ required "system is required" .Values.system }}
harborline.io/tier: {{ .Values.tier }}
harborline.io/data-classification: {{ .Values.dataClassification }}
harborline.io/environment: {{ .Values.environment }}
{{- end -}}

{{/* Digest-pinned image reference */}}
{{- define "gs.image" -}}
{{- $repo := required "image.repository is required" .Values.image.repository -}}
{{- $digest := required "image.digest is required (deploys are digest-pinned)" .Values.image.digest -}}
{{- printf "%s@%s" $repo $digest -}}
{{- end -}}

{{/* Restricted pod security context (PSS restricted / CIS 4.2.x / 4.6.x) */}}
{{- define "gs.podSecurityContext" -}}
runAsNonRoot: true
runAsUser: 10001
runAsGroup: 10001
fsGroup: 10001
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{- define "gs.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
runAsNonRoot: true
capabilities:
  drop: ["ALL"]
{{- end -}}

{{/* OpenTelemetry environment (SDK auto-configuration) */}}
{{- define "gs.otelEnv" -}}
{{- if .Values.observability.otel.enabled -}}
- name: OTEL_SERVICE_NAME
  value: {{ include "gs.fullname" . | quote }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ .Values.observability.otel.endpoint | quote }}
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: grpc
- name: OTEL_SEMCONV_STABILITY_OPT_IN
  value: http
- name: OTEL_TRACES_SAMPLER
  value: {{ .Values.observability.otel.sampler | quote }}
- name: OTEL_TRACES_SAMPLER_ARG
  value: {{ .Values.observability.otel.samplerArg | quote }}
- name: K8S_POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: K8S_NAMESPACE_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
- name: K8S_NODE_NAME
  valueFrom:
    fieldRef:
      fieldPath: spec.nodeName
- name: OTEL_RESOURCE_ATTRIBUTES
  value: {{ printf "service.namespace=%s,service.version=%s,deployment.environment.name=%s,k8s.pod.name=$(K8S_POD_NAME),k8s.namespace.name=$(K8S_NAMESPACE_NAME),k8s.node.name=$(K8S_NODE_NAME)" (default .Values.team .Values.observability.otel.serviceNamespace) (default .Chart.AppVersion .Values.image.tag) .Values.environment | quote }}
{{- end }}
{{- end -}}
