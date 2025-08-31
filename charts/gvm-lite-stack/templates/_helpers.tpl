{{- define "gvm-lite-stack.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "gvm-lite-stack.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "gvm-lite-stack.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "gvm-lite-stack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "gvm-lite-stack.labels" -}}
app.kubernetes.io/name: {{ include "gvm-lite-stack.name" . }}
helm.sh/chart: {{ include "gvm-lite-stack.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "gvm-lite-stack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gvm-lite-stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "gvm-lite-stack.clusterDomain" -}}
{{- default "cluster.local" .Values.clusterDomain -}}
{{- end -}}

{{- define "gvm-lite-stack.scannerFQDN" -}}
{{- printf "%s.%s.svc.%s" .Values.scanner.service.name .Release.Namespace (include "gvm-lite-stack.clusterDomain" .) -}}
{{- end -}}
