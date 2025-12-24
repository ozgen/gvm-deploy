# gvm-lite-stack

Helm chart that deploys a lightweight Greenbone stack on Kubernetes:

* **gvmd-lite** (API)
* **gvmr-lite** (report formats & rendering service)
* **openvas-service** (scanner)
* **feed-service** (feeds / NVT sync)
* **gsa-lite** (frontend)
* **Bitnami PostgreSQL** subchart (enabled by default)

---

## Prerequisites

* Helm ≥ 3.10
* `kubectl` pointing at your cluster (e.g. Minikube)
* Docker (only required for building local images)

---

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

---

## Pull chart dependencies

```bash
cd charts/gvm-lite-stack
helm dependency build
```

---

## Render manifests (no deploy)

```bash
helm template gvm ../gvm-lite-stack -n gvm > gvm-lite-stack.yaml
# or from repo root
helm template gvm charts/gvm-lite-stack -n gvm > gvm-lite-stack.yaml
```

```bash
helm template gvm charts/gvm-lite-stack -n gvm \
  -f charts/gvm-lite-stack/values.yaml > gvm-lite-stack.yaml
```

---

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

---

## Quick checks

```bash
kubectl get pods -n gvm
kubectl get svc -n gvm
```

Service endpoints inside the cluster:

* Frontend (NodePort): **gsa-lite** → node port **30080**
* API service: `gvmd-lite.gvm.svc.cluster.local:8082`
* Report-render service: `gvmr-lite.gvm.svc.cluster.local:8084`
* Scanner service: `openvas-service.gvm.svc.cluster.local:3001`

---

## Development loop with local images (Minikube)

Build images **inside** Minikube and point the chart at those tags:

```bash
eval "$(minikube docker-env)"

docker build -t ozgenm/gvmd-lite:dev path/to/gvmd-lite
docker build -t ozgenm/gvmr-lite:dev path/to/gvmr-lite
docker build -t ozgenm/scanner:dev   path/to/scanner
docker build -t ozgenm/feed-img:dev  path/to/feed
docker build -t gsa-lite:prod        path/to/gsa
```

Deploy using local images:

```bash
helm upgrade --install gvm charts/gvm-lite-stack -n gvm --create-namespace \
  --set gvmdLite.image.repository=ozgenm/gvmd-lite \
  --set gvmdLite.image.tag=dev \
  --set gvmdLite.image.pullPolicy=Always \
  --set gvmrLite.image.repository=ozgenm/gvmr-lite \
  --set gvmrLite.image.tag=dev \
  --set gvmrLite.image.pullPolicy=Always \
  --set scanner.image.repository=ozgenm/scanner \
  --set scanner.image.tag=dev \
  --set scanner.image.pullPolicy=Always \
  --set feed.image.repository=ozgenm/feed-img \
  --set feed.image.tag=dev \
  --set feed.image.pullPolicy=Always
```

---

## PostgreSQL dependency

This chart includes the **Bitnami PostgreSQL** Helm chart as a dependency:

```yaml
dependencies:
  - name: postgresql
    version: 16.3.0
    repository: oci://registry-1.docker.io/bitnamicharts
    condition: postgresql.enabled
```

### Default (enabled)

```yaml
postgresql:
  enabled: true
  architecture: standalone
  auth:
    username: gvmd
    password: gvmdpw   # override in production
    database: gvmd-lite-service
  primary:
    persistence:
      enabled: true
      size: 8Gi
```

This creates:

* a StatefulSet (`gvm-postgresql-0`)
* a Service (`gvm-postgresql`)
* a Secret containing DB credentials

`gvmd-lite` automatically connects to this DB when enabled.

---

## External PostgreSQL (optional)

```bash
helm upgrade --install gvm charts/gvm-lite-stack -n gvm --create-namespace \
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

## Notification integrations (optional)

`gvmd-lite` supports outbound notifications via **SMTP**, **Slack**, and **Azure Blob Storage**.
All integrations are **disabled by default**.

### SMTP

```yaml
gvmdLite:
  env:
    SMTP_ENABLED: "1"
    SMTP_HOST: smtp.example.com
    SMTP_PORT: "587"
    SMTP_FROM: noreply@example.com
  secrets:
    SMTP_USERNAME: myuser
    SMTP_PASSWORD: mypassword
```

### Slack

```yaml
gvmdLite:
  env:
    SLACK_ENABLED: "1"
  secrets:
    SLACK_WEBHOOK_URL: https://hooks.slack.com/services/xxx/yyy/zzz
```

### Azure Blob

```yaml
gvmdLite:
  env:
    AZURE_CONTAINER_ENABLED: "1"
    AZURE_STORAGE_ACCOUNT_NAME: myaccount
    AZURE_CONTAINER_NAME: mycontainer
  secrets:
    AZURE_CONTAINER_ACCESS_KEY: myaccesskey
```

---

## Troubleshooting quick commands

* Render with debug:

  ```bash
  helm template gvm charts/gvm-lite-stack -n gvm --debug
  ```
* Watch rollout:

  ```bash
  kubectl -n gvm rollout status deploy/gvmd-lite
  ```
* Describe pod issues:

  ```bash
  kubectl -n gvm describe pod -l app=gvmd-lite
  ```

---

## Persistent Volume Claims (PVCs)

The chart creates the following PVCs by default:

| Component        | Purpose                   | Size |
| ---------------- | ------------------------- | ---- |
| PostgreSQL       | Database storage          | 8Gi  |
| Feed – plugins   | NVT feed data             | 5Gi  |
| Feed – notus     | Notus feed data           | 2Gi  |
| Feed – logs      | Feed sync logs            | 1Gi  |
| gvmr-lite – work | Report rendering work dir | 1Gi  |

PVC sizes can be adjusted in `values.yaml` as needed.

---