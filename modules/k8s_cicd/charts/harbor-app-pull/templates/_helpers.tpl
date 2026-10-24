{{- define "harbor-app-pull.jobSpec" -}}
backoffLimit: 2
activeDeadlineSeconds: 600
template:
  metadata:
    labels:
      app.kubernetes.io/name: {{ .Release.Name }}
  spec:
    serviceAccountName: {{ .Release.Name }}
    automountServiceAccountToken: true
    restartPolicy: Never
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      runAsGroup: 1000
      seccompProfile:
        type: RuntimeDefault
    containers:
      - name: bootstrap
        image: python:3.13-slim
        command: ["python3", "-B", "/bootstrap/application_pull_auth.py"]
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 500m
            memory: 128Mi
        env:
          - name: HARBOR_URL
            value: {{ .Values.harborURL | quote }}
          - name: REGISTRY_HOST
            value: {{ .Values.registry | quote }}
          - name: HARBOR_PROJECT
            value: {{ .Values.project | quote }}
          - name: ROBOT_DURATION_DAYS
            value: {{ .Values.durationDays | quote }}
          - name: APPLICATION_NAMESPACES
            value: {{ .Values.namespaces | toJson | quote }}
          - name: HARBOR_ADMIN_PASSWORD
            valueFrom:
              secretKeyRef:
                name: {{ .Values.adminSecret }}
                key: HARBOR_ADMIN_PASSWORD
        volumeMounts:
          - name: script
            mountPath: /bootstrap
            readOnly: true
    volumes:
      - name: script
        configMap:
          name: {{ .Release.Name }}
{{- end }}
