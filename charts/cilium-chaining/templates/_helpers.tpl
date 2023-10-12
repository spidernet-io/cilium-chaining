{{/*
Expand the name of the chart.
*/}}
{{- define "cilium-chaining.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cilium-chaining.fullname" -}}
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
{{- define "cilium-chaining.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cilium-chaining.labels" -}}
helm.sh/chart: {{ include "cilium-chaining.chart" . }}
{{ include "cilium-chaining.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cilium-chaining.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cilium-chaining.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cilium-chaining.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cilium-chaining.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
return the image
*/}}
{{- define "cilium-chaining.image" -}}
{{- $registry := .Values.cilium.image.registry -}}
{{- $repository := .Values.cilium.image.repository -}}
{{- if .Values.global.imageRegistryOverride }}
    {{- printf "%s/%s" .Values.global.imageRegistryOverride $repository -}}
{{ else if $registry }}
    {{- printf "%s/%s" $registry $repository -}}
{{- else -}}
    {{- printf "%s" $repository -}}
{{- end -}}
{{- if .Values.cilium.image.tag -}}
    {{- printf ":%s" .Values.cilium.image.tag -}}
{{- else -}}
    {{- printf ":v%s" .Chart.AppVersion -}}
{{- end -}}
{{- end -}}
