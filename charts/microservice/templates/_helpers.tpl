{{- define "appname" }}
{{- if ne .Values.global.overrideName ""}}
{{- .Values.global.overrideName}}
{{- else}}
{{- .Release.Name }}
{{- end }}
{{- end }}

#-------------------------------------------------------------------------------
#---- DEFINING LABELS                                                      ----
#-------------------------------------------------------------------------------

{{- define "common.labels" }}
chart: "{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}"
release: {{ include "appname" . }}
env: {{ .Values.global.env }}
version: {{ .Values.global.appVersion }}
{{- if .Values.global.additionalLabels }}
{{- .Values.global.additionalLabels | toYaml | nindent 0 }}
{{- end }}
{{- end }}

{{- define "app.labels" }}
{{- include "common.labels" . | nindent 0 }}
tags.datadoghq.com/service: {{ include "appname" . }}
tags.datadoghq.com/version: {{ .Values.global.appVersion }}
{{- end }}


{{- define "worker.labels" }}
{{- include "common.labels" . | nindent 0 }}
tags.datadoghq.com/service: {{ printf "%s-worker" (include "appname" .) }}
tags.datadoghq.com/version: {{ .Values.global.appVersion }}
{{- end }}

{{- define "migration.labels" }}
{{- include "common.labels" . | nindent 0 }}
app: {{ printf "%s-migrator" .Release.Name }}
tags.datadoghq.com/service: {{ printf "%s-migrator" (include "appname" .) }}
tags.datadoghq.com/version: {{ .Values.global.appVersion }}
{{- end }}

#-------------------------------------------------------------------------------
#---- DEFINING ANNOTATIONS                                                 ----
#-------------------------------------------------------------------------------

{{- define "common.annotations" }}
timestamp: {{ now | unixEpoch | quote }}
{{ printf "ad.datadoghq.com/%s.logs" (include "appname" .) }}: |-
  [{
    "source":"nestjs",
    "log_processing_rules": [{
    "type":"multi_line",
    "name": "nest_start_line",
    "pattern": "\\[Nest\\]"
    }],
    "tags":["pod_ip:%%host%%"]
  }]
{{- end }}

{{- define "sa.annotations" }}
iam.gke.io/gcp-service-account: {{ printf "%s@%s.iam.gserviceaccount.com" .Values.serviceAccount .Values.global.project_id | quote }}
helm.sh/hook: pre-install
helm.sh/hook-weight: "0"
helm.sh/hook-delete-policy: hook-failed,before-hook-creation
{{- end }}

{{- define "secrets.annotations" }}
helm.sh/hook: pre-install,pre-upgrade
helm.sh/hook-weight: "0"
helm.sh/hook-delete-policy: before-hook-creation
{{- end }}

{{- define "migration.annotations" }}
timestamp: {{ now | unixEpoch | quote }}
{{ printf "ad.datadoghq.com/%s-migrator.logs" (include "appname" .) }}: |-
  [{
    "source":"nestjs",
    "log_processing_rules": [{
    "type":"multi_line",
    "name": "nest_start_line",
    "pattern": "\\[Nest\\]"
    }],
    "tags":["pod_ip:%%host%%"]
  }]
helm.sh/hook: pre-install,pre-upgrade 
helm.sh/hook-weight: "1"
helm.sh/hook-delete-policy: before-hook-creation
{{- end }}

{{- define "linked_service.annotations" }}
timestamp: {{ now | unixEpoch | quote }}
"ad.datadoghq.com/{{ .Values.linked_service.name }}.logs": |-
  [{
    "source":"{{ .Values.linked_service.name }}",
    "tags":["pod_ip:%%host%%"]
  }]
{{- end }}

{{- define "linked_service.labels" }}
{{- include "common.labels" . | nindent 0 }}
tags.datadoghq.com/service: {{ .Values.linked_service.name }}
{{- end }}

{{- define "sa.linked_service.annotations" }}
iam.gke.io/gcp-service-account: {{ printf "%s@%s.iam.gserviceaccount.com" .Values.linked_service.name .Values.global.project_id | quote }}
helm.sh/hook: pre-install
helm.sh/hook-weight: "0"
helm.sh/hook-delete-policy: hook-failed
{{- end }}

