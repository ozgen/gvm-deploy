# gvm-lite-stack

Helm chart that deploys a lightweight Greenbone stack on Kubernetes:

* **gvmd-lite** (API)
* **openvas-service** (scanner)
* **feed-service** (feeds/NVT sync)
* **gsa-lite** (frontend)
* **Bitnami PostgreSQL** subchart (enabled by default)

## Prereqs

* Helm ≥ 3.10
* `kubectl` pointing at your cluster (e.g., Minikube)
* Docker (only if you build local images)

## Chart tree

```
charts/
  gvm-lite-stack/
    Chart.yaml
    Chart.lock
    values.yaml          
    templates/
    charts/             
```

## Pull chart dependencies

```bash
cd charts/gvm-lite-stack
helm dependency build
```

## Render manifests (no deploy)

```bash
helm template gvm ../gvm-lite-stack -n gvm > gvm-lite-stack.yaml
# (or from repo root)
helm template gvm charts/gvm-lite-stack -n gvm > gvm-lite-stack.yaml
```

```bash
helm template gvm charts/gvm-lite-stack -n gvm \
  -f charts/gvm-lite-stack/values.yaml > gvm-lite-stack.yaml
```

## Deploy (default values.yaml)

```bash
helm install gvm charts/gvm-lite-stack -n gvm --create-namespace \
  -f charts/gvm-lite-stack/values.yaml
```

### Upgrade after changes

```bash
helm upgrade gvm charts/gvm-lite-stack -n gvm \
  -f charts/gvm-lite-stack/values.yaml
```

### Uninstall

```bash
helm uninstall gvm -n gvm
```

## Quick checks

```bash
kubectl get pods -n gvm
kubectl get svc -n gvm
```

* Frontend (NodePort): `gsa-lite` on **node port 30080**
* API service: `gvmd-lite.gvm.svc.cluster.local:8082`
* Scanner service: `openvas-service.gvm.svc.cluster.local:3001`

## Dev loop with local images (Minikube)

Build **into** Minikube and point the chart at those tags:

```bash
eval "$(minikube docker-env)"

# build images with your preferred tags
docker build -t ozgenm/gvmd-lite:dev path/to/gvmd-lite
docker build -t ozgenm/scanner:dev     path/to/scanner
docker build -t ozgenm/feed-img:dev    path/to/feed
docker build -t gsa-lite:prod          path/to/gsa   # you already use this tag

# deploy using those tags (override only the image bits)
helm upgrade --install gvm charts/gvm-lite-stack -n gvm --create-namespace \
  --set gvmdLite.image.repository=ozgenm/gvmd-lite \
  --set gvmdLite.image.tag=dev \
  --set gvmdLite.image.pullPolicy=Always \
  --set scanner.image.repository=ozgenm/scanner \
  --set scanner.image.tag=dev \
  --set scanner.image.pullPolicy=Always \
  --set feed.image.repository=ozgenm/feed-img \
  --set feed.image.tag=dev \
  --set feed.image.pullPolicy=Always
```

---

## PostgreSQL Dependency

This chart includes the **Bitnami PostgreSQL** Helm chart as a dependency (see `Chart.yaml`):

```yaml
dependencies:
  - name: postgresql
    version: 16.3.0
    repository: oci://registry-1.docker.io/bitnamicharts
    condition: postgresql.enabled
```

### Default (enabled)

By default, the Bitnami subchart is installed and a `gvmd` database is created:

```yaml
postgresql:
  enabled: true
  architecture: standalone
  auth:
    username: "gvmd"
    password: "gvmdpw"            # change or override in production
    database: "gvmd-lite-service"
  primary:
    persistence:
      enabled: true
      size: 8Gi
```

This creates a StatefulSet (`gvm-postgresql-0`), a Service (`gvm-postgresql`), and a Secret (`gvm-postgresql` with the password).
`gvmd-lite` automatically uses this internal Postgres if `postgresql.enabled=true`.

## External Postgres (optional)

The values enable Bitnami Postgres by default. To use an **external** DB:

```bash
helm upgrade --install gvm charts/gvm-lite-stack -n gvm --create-namespace \
  -f charts/gvm-lite-stack/values.yaml \
  --set postgresql.enabled=false \
  --set gvmdLite.externalDb.enabled=true \
  --set gvmdLite.externalDb.host="postgres.external.svc" \
  --set gvmdLite.externalDb.port=5432 \
  --set gvmdLite.externalDb.user="user" \
  --set gvmdLite.externalDb.name="gvmd-lite-service" \
  --set gvmdLite.externalDb.passwordSecretName="my-external-pg" \
  --set gvmdLite.externalDb.passwordSecretKey="DB_PASSWORD"
```

---

## Notification Integrations (optional)

`gvmd-lite` supports optional outbound notifications via **SMTP**, **Slack**, and **Azure Blob Storage**.
All integrations are **disabled by default** (`*_ENABLED=0`).

To enable one or more integrations, set the following in `values.yaml` or via `--set-string` flags.

### SMTP (Email)

```yaml
gvmdLite:
  env:
    SMTP_ENABLED: "1"
    SMTP_HOST: "smtp.example.com"
    SMTP_PORT: "587"
    SMTP_FROM: "noreply@example.com"
  secrets:
    SMTP_USERNAME: "myuser"
    SMTP_PASSWORD: "mypassword"
```

### Slack

```yaml
gvmdLite:
  env:
    SLACK_ENABLED: "1"
  secrets:
    SLACK_WEBHOOK_URL: "https://hooks.slack.com/services/xxx/yyy/zzz"
```

### Azure Blob

```yaml
gvmdLite:
  env:
    AZURE_CONTAINER_ENABLED: "1"
    AZURE_STORAGE_ACCOUNT_NAME: "myaccount"
    AZURE_CONTAINER_NAME: "mycontainer"
  secrets:
    AZURE_CONTAINER_ACCESS_KEY: "myaccesskey"
```

### Default (disabled)

By default, all integrations are set to `"0"` (disabled) in `values.yaml`:

```yaml
SMTP_ENABLED: "0"
SLACK_ENABLED: "0"
AZURE_CONTAINER_ENABLED: "0"
```

### Example: enable SMTP during install

```bash
helm upgrade --install gvm charts/gvm-lite-stack -n gvm \
  --set-string gvmdLite.env.SMTP_ENABLED=1 \
  --set-string gvmdLite.env.SMTP_HOST="smtp.example.com" \
  --set-string gvmdLite.env.SMTP_FROM="noreply@example.com" \
  --set-string gvmdLite.secrets.SMTP_USERNAME="$SMTP_USERNAME" \
  --set-string gvmdLite.secrets.SMTP_PASSWORD="$SMTP_PASSWORD"
```

---

## Troubleshooting quickies

* Render with debug:
  `helm template gvm charts/gvm-lite-stack -n gvm --debug`
* Watch rollout:
  `kubectl -n gvm rollout status deploy/gvmd-lite`
* Describe events/errors:
  `kubectl -n gvm describe pod -l app=gvmd-lite`
* Check env seen by the process (PID 1):
  `kubectl exec -n gvm deploy/gvmd-lite -- sh -c "tr '\0' '\n' </proc/1/environ | egrep 'SCANNER_HOST|DB_HOST'"`

## Notes on your current `values.yaml`

* **Scanner uses hostNetwork: true**. That’s good for raw socket scans; if you hit permission issues with `nmap` inside
  VTs, ensure the scanner container has the right Linux capabilities or setcaps in the image.
* **GSA NodePort** is **30080** (already set). `minikube service gsa-lite -n gvm --url` prints the URL.
* **Feed PVC sizes** match your earlier setup: plugins 5Gi, notus 2Gi, logs 1Gi.

---
