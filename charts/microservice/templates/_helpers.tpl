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

{{- define "common.labels" -}}
chart: "{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}"
release: {{ include "appname" . }}
env: {{ .Values.global.env }}
version: {{ .Values.global.appVersion }}
{{- if .Values.global.additionalLabels }}
{{- .Values.global.additionalLabels | toYaml | nindent 0 }}
{{- end }}
{{- end }}

{{- define "app.labels" -}}
{{- include "common.labels" . | trim }}
microservice: "true"
"tags.datadoghq.com/service": {{ include "appname" . }}
"tags.datadoghq.com/version": {{ .Values.global.appVersion }}
{{- end }}

{{- define "worker.labels" -}}
{{- include "common.labels" . | trim}}
microservice: "true"
"tags.datadoghq.com/service": {{ printf "%s-worker" (include "appname" .) }}
"tags.datadoghq.com/version": {{ .Values.global.appVersion }}
{{- end }}

{{- define "migration.labels" -}}
{{- include "common.labels" . | trim }}
app: {{ printf "%s-migrator" .Release.Name }}
"tags.datadoghq.com/service": {{ printf "%s-migrator" (include "appname" .) }}
"tags.datadoghq.com/version": {{ .Values.global.appVersion }}
{{- end }}

{{- define "microservice.selectorLabels" -}}
app: {{ .Release.Name }}
component: primary
{{- end }}

#-------------------------------------------------------------------------------
#---- DEFINING ANNOTATIONS                                                 ----
#-------------------------------------------------------------------------------

{{- define "common.annotations" -}}
timestamp: {{ now | unixEpoch | quote }}
"ad.datadoghq.com/{{ include "appname" . }}.logs": |-
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

{{- /*
  Worker pods run a container named "<release>-worker", so they need their own
  Datadog log annotation keyed to that exact container name. Without a matching
  key the agent falls back to source:<image-name> instead of source:nestjs — the
  NestJS pipeline never runs, worker debug logs are not status-remapped, and they
  leak into the 30-day index.

  The key is built from .Release.Name (NOT the overrideName-aware "appname"
  helper) so it always matches the worker container name, which deployments.yaml
  hardcodes to "<.Release.Name>-worker" regardless of global.overrideName.
*/}}
{{- define "worker.annotations" -}}
timestamp: {{ now | unixEpoch | quote }}
"ad.datadoghq.com/{{ .Release.Name }}-worker.logs": |-
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

{{- define "sa.annotations" -}}
"iam.gke.io/gcp-service-account": {{ printf "%s@%s.iam.gserviceaccount.com" .Values.serviceAccount .Values.global.project_id | quote }}
"helm.sh/hook": pre-install
"helm.sh/hook-weight": "0"
"helm.sh/hook-delete-policy": hook-failed,before-hook-creation
{{- end }}

{{- define "secrets.annotations" -}}
"helm.sh/hook": pre-install,pre-upgrade
"helm.sh/hook-weight": "0"
"helm.sh/hook-delete-policy": before-hook-creation
{{- end }}

{{- define "migration.annotations" -}}
timestamp: {{ now | unixEpoch | quote }}
"ad.datadoghq.com/{{ include "appname" . }}-migrator.logs": |-
  [{
    "source":"nestjs",
    "log_processing_rules": [{
    "type":"multi_line",
    "name": "nest_start_line",
    "pattern": "\\[Nest\\]"
    }],
    "tags":["pod_ip:%%host%%"]
  }]
"helm.sh/hook": pre-install,pre-upgrade 
"helm.sh/hook-weight": "1"
"helm.sh/hook-delete-policy": before-hook-creation
{{- end }}

{{- define "linked_service.annotations" -}}
timestamp: {{ now | unixEpoch | quote }}
"ad.datadoghq.com/{{ .Values.linked_service.name }}.logs": |-
  [{
    "source":"{{ .Values.linked_service.name }}",
    "tags":["pod_ip:%%host%%"]
  }]
{{- end }}

{{- define "linked_service.labels" -}}
{{- include "common.labels" . | trim }}
"tags.datadoghq.com/service": {{ .Values.linked_service.name }}
{{- end }}

{{- define "sa.linked_service.annotations" -}}
"iam.gke.io/gcp-service-account": {{ printf "%s@%s.iam.gserviceaccount.com" .Values.linked_service.name .Values.global.project_id | quote }}
"helm.sh/hook": pre-install
"helm.sh/hook-weight": "0"
"helm.sh/hook-delete-policy": hook-failed
{{- end }}

{{/*
Parameterized helpers for the new `linked_services` (plural) list. Callers pass a dict
with `name` (the service name) and `ctx` (root context, for labels that depend on global).
The legacy `linked_service.*` helpers above stay for backwards compat with single-object users.
*/}}

{{- define "linked_services.annotations" -}}
{{- $name := .name -}}
timestamp: {{ now | unixEpoch | quote }}
"ad.datadoghq.com/{{ $name }}.logs": |-
  [{
    "source":"{{ $name }}",
    "tags":["pod_ip:%%host%%"]
  }]
{{- end }}

{{- define "linked_services.labels" -}}
{{- $name := .name -}}
{{- with .ctx -}}
{{ include "common.labels" . | trim }}
{{- end }}
"tags.datadoghq.com/service": {{ $name }}
{{- end }}

#-------------------------------------------------------------------------------
#---- ALLOYDB AUTH PROXY (opt-in native sidecar, DEVOPS-513)               ----
#-------------------------------------------------------------------------------

{{- /*
  Whether the AlloyDB Auth Proxy sidecar runs in a target's pod.
  Call with (dict "ctx" $ "target" "primary") or (dict "ctx" $ "target" "worker").
  Renders "true" when enabled and "" otherwise, so callers test it with `if`.

  The worker inherits alloydbAuthProxy.enabled unless worker.alloydbAuthProxy.enabled
  is set, and an explicit false there turns the worker off. `default` is never used
  on these booleans because it treats false as unset.
*/}}
{{- define "alloydbAuthProxy.enabled" -}}
{{- $cfg := .ctx.Values.alloydbAuthProxy | default dict -}}
{{- $on := dig "enabled" false $cfg -}}
{{- if eq .target "worker" -}}
{{- $workerCfg := dig "alloydbAuthProxy" dict (.ctx.Values.worker | default dict) | default dict -}}
{{- if and (hasKey $workerCfg "enabled") (not (kindIs "invalid" (index $workerCfg "enabled"))) -}}
{{- $on = index $workerCfg "enabled" -}}
{{- end -}}
{{- end -}}
{{- if $on -}}true{{- end -}}
{{- end }}

{{- /*
  The proxy as a native sidecar: an initContainers entry with restartPolicy Always
  (Kubernetes 1.29+). The kubelet starts the next init container and the app
  containers only once its startupProbe passes, and restarts it on its own if it
  exits or fails its livenessProbe. It has no readinessProbe on purpose: a native
  sidecar's readiness counts toward the pod's, so a not-ready proxy (upstream
  documents /readiness as failing while the instance is unreachable) would take
  API pods out of their Service.
  Call with the root context.
*/}}
{{- define "alloydbAuthProxy.container" -}}
{{- $cfg := .Values.alloydbAuthProxy | default dict -}}
{{- if not $cfg.instanceUri -}}
{{- fail "alloydbAuthProxy.instanceUri is required when the AlloyDB Auth Proxy is enabled for the primary or the worker (projects/PROJECT/locations/REGION/clusters/CLUSTER/instances/INSTANCE)" -}}
{{- end -}}
{{- if or (not $cfg.port) (eq ($cfg.port | toString) "0") -}}
{{- fail "alloydbAuthProxy.port must be a non-zero port number when the AlloyDB Auth Proxy is enabled for the primary or the worker (default 5432)" -}}
{{- end -}}
{{- if or (not $cfg.healthPort) (eq ($cfg.healthPort | toString) "0") -}}
{{- fail "alloydbAuthProxy.healthPort must be a non-zero port number when the AlloyDB Auth Proxy is enabled for the primary or the worker (default 9090)" -}}
{{- end -}}
- name: alloydb-auth-proxy
  image: {{ printf "%s:%s" $cfg.image ($cfg.tag | toString) }}
  imagePullPolicy: {{ $cfg.imagePullPolicy }}
  restartPolicy: Always
  args:
    - {{ $cfg.instanceUri | quote }}
    - "--structured-logs"
    - "--health-check"
    - "--http-address=0.0.0.0"
    - {{ printf "--http-port=%v" $cfg.healthPort | quote }}
    - {{ printf "--port=%v" $cfg.port | quote }}
    - "--address=127.0.0.1"
    {{- if $cfg.publicIp }}
    - "--public-ip"
    {{- end }}
  startupProbe:
    httpGet:
      path: /startup
      port: {{ $cfg.healthPort }}
    periodSeconds: 1
    timeoutSeconds: 1
    failureThreshold: 60
  livenessProbe:
    httpGet:
      path: /liveness
      port: {{ $cfg.healthPort }}
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
  {{- with $cfg.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  securityContext:
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
{{- end }}

{{- /*
  The REPORTING_AUTH_PROXY_PORT env entry for an app container whose pod runs the
  proxy, so the app and the proxy always agree on the port. Call with
  (dict "ctx" $ "params" (list <parameters maps the container renders>)).
  Fails when any of those maps also sets the variable (after the chart's
  upper-case and "-" to "_" mapping), since that would render a duplicate env name.
*/}}
{{- define "alloydbAuthProxy.appEnv" -}}
{{- range $params := .params -}}
{{- range $key, $_ := $params -}}
{{- if eq (upper $key | replace "-" "_") "REPORTING_AUTH_PROXY_PORT" -}}
{{- fail (printf "parameter %q sets REPORTING_AUTH_PROXY_PORT, which the chart sets itself while alloydbAuthProxy is enabled for this deployment: remove it from parameters/worker.parameters" $key) -}}
{{- end -}}
{{- end -}}
{{- end -}}
- name: REPORTING_AUTH_PROXY_PORT
  value: {{ dig "port" "" (.ctx.Values.alloydbAuthProxy | default dict) | toString | quote }}
{{- end }}
