
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
labels:
  chart: "{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}"
  release: {{ include "appname" . }}
  env: {{ .Values.global.env }}
  version: {{ default .Values.global.app_version "1.0.0" }}
{{- end }}

{{- define "all.labels" }}
{{- include "common.labels" . }}
{{- end }}

{{- define "migration.labels" }}
{{- include "common.labels" . }}
  app: {{ printf "%s-migration" .Release.Name }}
{{- end }}

#-------------------------------------------------------------------------------
#---- DEFINING ANNOTATIONS                                                 ----
#-------------------------------------------------------------------------------

{{- define "common.annotations" }}
annotations:
  timestamp: {{ now | unixEpoch | quote }}
{{- end }}

{{- define "migration.annotations" }}
annotations:
  helm.sh/hook: pre-install,pre-upgrade
  helm.sh/hook-weight: "1"
  helm.sh/hook-delete-policy: hook-succeeded,hook-failed
{{- end }}

{{- define "sa.annotations" }}
annotations:
  iam.gke.io/gcp-service-account: {{ printf "%s@%s.iam.gserviceaccount.com" .Values.serviceAccount .Values.global.project_id | quote }}
  helm.sh/hook: pre-install
  helm.sh/hook-weight: "0"
  helm.sh/hook-delete-policy: hook-failed
{{- end }}
