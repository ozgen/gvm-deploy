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

### Required

* **Helm** (v3.x)

    * Verify: `helm version`
* **helm-unittest** plugin (for unit tests)

    * Install: `helm plugin install https://github.com/helm-unittest/helm-unittest`
    * Verify: `helm plugin list | grep unittest`

### Recommended

* **kubeconform** (validates rendered manifests against Kubernetes schemas)

    * macOS (Homebrew): `brew install kubeconform`
    * Linux: install from GitHub releases (see CI workflow)
    * Verify: `kubeconform -v`
* **yamlfmt** (formats / checks YAML style)

    * Install (Go): `go install github.com/google/yamlfmt/cmd/yamlfmt@latest`
    * Ensure it’s on PATH: `export PATH="$PATH:$HOME/go/bin"`
    * Verify: `yamlfmt -version` or `yamlfmt --version`

> Note: Helm templates under `charts/**/templates/` are **not valid YAML** until rendered, so formatting is applied only
> to `Chart.yaml`, `values*.yaml`, and `tests/**/*.yaml`.

---

## Development Commands (Makefile)

This repository uses a Makefile to keep common actions consistent locally and in CI.

> Chart location: `charts/gvm-lite-stack`

### Format non-template YAML only

* Format files in-place:

    * `make fmt`
* Check formatting CI-style, fails if formatting would change:

    * `make fmt-check`

### Lint

* Run Helm lint:

    * `make lint`

### Unit tests

* Run Helm unit tests:

    * `make test`

### Render manifests

* Render the chart to a local file:

    * `make render`
    * Output: `/tmp/gvm-lite-stack.rendered.yaml`

### Schema validation rendered output

* Validate rendered manifests with kubeconform:

    * `make validate`

### Coverage gate Helm template coverage

* Ensure every template has at least one unit test referencing it:

    * `make coverage`

### Full local check recommended before pushing

* Run everything CI expects:

    * `make check`

---

## Chart tree

```text
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

## Render manifests no deploy

```bash
helm template gvm ../gvm-lite-stack -n gvm > gvm-lite-stack.yaml
```

Or from the repository root:

```bash
helm template gvm charts/gvm-lite-stack -n gvm > gvm-lite-stack.yaml
```

Render with explicit values:

```bash
helm template gvm charts/gvm-lite-stack -n gvm \
  -f charts/gvm-lite-stack/values.yaml > gvm-lite-stack.yaml
```

---

## Deploy default values.yaml

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

* Frontend NodePort: **gsa-lite** to node port **30080**
* API service: `gvmd-lite.gvm.svc.cluster.local:8082`
* Report-render service: `gvmr-lite.gvm.svc.cluster.local:8084`
* Scanner service: `openvas-service.gvm.svc.cluster.local:3001`

---

## Development loop with local images Minikube

Build images **inside** Minikube and point the chart at those tags:

```bash
eval "$(minikube docker-env)"

docker build -t ozgenm/gvmd-lite:dev path/to/gvmd-lite
docker build -t ozgenm/gvmr-lite:dev path/to/gvmr-lite
docker build -t ozgenm/scanner:dev path/to/scanner
docker build -t ozgenm/feed-img:dev path/to/feed
docker build -t gsa-lite:prod path/to/gsa
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

## Container scanning / OCI image targets

Container scanning support is optional and requires a `gvmd-lite` image built with the `container_scanning` build tag.

By default, container scanning is disabled:

```yaml
gvmdLite:
  env:
    ENABLE_CONTAINER_SCANNING: "false"
```

To enable container scanning, use the feature image and enable the runtime flag:

```bash
helm upgrade --install gvm charts/gvm-lite-stack -n gvm --create-namespace \
  --set gvmdLite.image.repository=ozgenm/gvmd-lite-features \
  --set gvmdLite.image.tag=latest \
  --set gvmdLite.env.ENABLE_CONTAINER_SCANNING="true"
```

Or configure it in `values.yaml`:

```yaml
gvmdLite:
  image:
    repository: ozgenm/gvmd-lite-features
    tag: latest
  env:
    ENABLE_CONTAINER_SCANNING: "true"
```

Both parts are required:

| Requirement                       | Why                                                                         |
|-----------------------------------|-----------------------------------------------------------------------------|
| `ozgenm/gvmd-lite-features` image | Contains the backend code compiled with the `container_scanning` build tag. |
| `ENABLE_CONTAINER_SCANNING=true`  | Enables the feature at runtime.                                             |

Setting `ENABLE_CONTAINER_SCANNING=true` while still using the default `ozgenm/gvmd-lite` image is not enough, because
the container scanning code is not compiled into that image.

When enabled, OCI image target APIs and related frontend features become available.

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

### Default enabled

```yaml
postgresql:
  enabled: true
  architecture: standalone
  auth:
    username: gvmd
    password: gvmdpw # override in production
    database: gvmd-lite-service
  primary:
    persistence:
      enabled: true
      size: 8Gi
```

This creates:

* a StatefulSet: `gvm-postgresql-0`
* a Service: `gvm-postgresql`
* a Secret containing DB credentials

`gvmd-lite` automatically connects to this DB when enabled.

---

## External PostgreSQL optional

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

## Notification integrations optional

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

Render with debug:

```bash
helm template gvm charts/gvm-lite-stack -n gvm --debug
```

Watch rollout:

```bash
kubectl -n gvm rollout status deploy/gvmd-lite
```

Describe pod issues:

```bash
kubectl -n gvm describe pod -l app=gvmd-lite
```

Check API logs:

```bash
kubectl -n gvm logs deploy/gvmd-lite
```

Check mounted feed directories:

```bash
kubectl -n gvm exec deploy/gvmd-lite -- ls -la /var/lib/openvas/plugins
kubectl -n gvm exec deploy/gvmd-lite -- ls -la /var/lib/notus/advisories
kubectl -n gvm exec deploy/gvmd-lite -- ls -la /var/lib/gvm
```

---

## Persistent Volume Claims PVCs

The chart creates the following PVCs by default:

| Component        | Purpose                                  | Size |
|------------------|------------------------------------------|------|
| PostgreSQL       | Database storage                         | 8Gi  |
| Feed – plugins   | NVT feed data                            | 5Gi  |
| Feed – notus     | Notus feed data                          | 2Gi  |
| Feed – gvm       | Report format and scan configs feed data | 1Gi  |
| Feed – logs      | Feed sync logs                           | 1Gi  |
| gvmr-lite – work | Report rendering work dir                | 1Gi  |

PVC sizes can be adjusted in `values.yaml` as needed.
