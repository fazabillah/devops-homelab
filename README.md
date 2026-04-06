# DevSecOps Homelab Portfolio

A homelab project built on a Mac Mini running two Ubuntu VMs on Parallels Desktop Pro. Demonstrates a production-style DevOps pipeline covering infrastructure provisioning, CI/CD, GitOps, observability, and operational automation. Security scanning is integrated directly into the pipeline — CVE gating, manifest misconfiguration checks, secret scanning, and SBOM generation run on every commit. Targeting DevOps and platform engineering roles.

## Infrastructure

| Component | Details |
|---|---|
| Host | Mac Mini 2018, macOS Sequoia, Parallels Desktop Pro |
| Control plane VM | Ubuntu 24.04.4 LTS (k3s-control), 4 CPU / 8GB RAM — K3s, ArgoCD, Prometheus, Grafana, Loki |
| Worker VM | Ubuntu 24.04.4 LTS (k3s-worker), 4 CPU / 8GB RAM — Oracle XE, Splunk, app workloads |
| Remote access | MacBook Air M4 via Tailscale VPN (stable 100.x.x.x IPs) |
| Kubernetes | K3s (lightweight distribution) |
| Container registry | Docker Hub (public) |

## CI/CD Pipeline

```
git push
  ↓
GitHub Actions (path-filtered per service)
  test → docker build (multi-stage)
       → trivy image scan (fails on CRITICAL/HIGH)
       → trivy config scan (K8s manifest misconfigurations)
       → trivy secret scan (hardcoded credentials)
       → SBOM generation (CycloneDX) uploaded as artifact
       → SARIF results uploaded to GitHub Security tab
  push to Docker Hub
  bot commit: updates Kustomize overlay with new image SHA
  ↓
ArgoCD detects manifest change (polls every 3 min)
  ↓
K3s cluster — rolling update
  (containers run non-root, read-only filesystem, no privilege escalation)
  ↓
Prometheus + Grafana (metrics)
Loki + Promtail (logs)
Splunk + Fluent Bit (enterprise log aggregation)
Dynatrace OneAgent (APM, distributed traces)
```

## Tech Stack

| Category | Tools |
|---|---|
| Container orchestration | Kubernetes (K3s), Docker |
| GitOps / CD | ArgoCD |
| CI | GitHub Actions |
| Package management | Helm, Kustomize (dev/staging/prod overlays) |
| Infrastructure as Code | Terraform (K8s namespaces, RBAC) |
| Metrics | Prometheus, Grafana |
| Logging | Loki, Promtail, Splunk, Fluent Bit |
| APM | Dynatrace OneAgent Operator |
| Security (shift-left) | Trivy (image CVE, K8s config, secrets), SBOM (CycloneDX), SARIF → GitHub Security tab |
| Database | Oracle XE 21c (StatefulSet, persistent volume) |
| Automation | Ansible, Bash scripting |
| Alternative platform | OpenShift Local (CRC) |
| Networking / VPN | Tailscale |

## What's Built

### Python/Flask Application (lab0)

A Flask API with a full DevSecOps pipeline — multi-stage Docker build, GitHub Actions CI with Trivy scanning and SBOM generation, Helm chart, Kustomize overlays for three environments, ArgoCD GitOps deployment to K3s, and Prometheus/Grafana/Loki observability.

### Java Spring Boot Application (lab1-java)

A logistics shipment screening API (Spring Boot 3.x, Java 21, Oracle XE backend). The CI pipeline runs Maven tests, builds a multi-stage Docker image, scans with Trivy, pushes to Docker Hub, and bot-commits the new image SHA to the Kustomize overlay. ArgoCD picks up the change and deploys to `java-dev`, `java-staging`, and `java-prod` namespaces with automated prune and self-heal.

- Oracle XE 21c deployed as a StatefulSet with persistent storage and seed data
- Splunk + Fluent Bit pipeline: logs forwarded from K3s pods to Splunk HEC, searchable in Splunk dashboards
- Prometheus ServiceMonitor scrapes `/actuator/prometheus`; Grafana dashboard shows JVM heap, HTTP request rate, error rate, and HikariCP connection pool

### Security (Shift-Left)

Security is integrated into CI, not bolted on after. Every image goes through three Trivy gates before it can reach the registry: a CVE scan that fails the pipeline on CRITICAL or HIGH severity, a Kubernetes manifest scan for misconfigurations, and a secret scan for hardcoded credentials. A CycloneDX SBOM is generated and uploaded as a GitHub Actions artifact. SARIF results land in the GitHub Security tab automatically.

At runtime, all containers run non-root with read-only filesystems and no privilege escalation. ArgoCD AppProject RBAC scopes what namespaces and repositories each application can touch.

This covers the shift-left layer of DevSecOps — catching vulnerabilities and misconfigurations before deployment. A production setup would add policy enforcement (OPA/Kyverno), secret management (Vault or Sealed Secrets), and runtime threat detection on top of this.

### Observability

- **Prometheus + Grafana** — cluster and application metrics, custom Grafana dashboard per service
- **Loki + Promtail** — log aggregation from all K3s pods
- **Splunk + Fluent Bit** — enterprise-grade log pipeline; Fluent Bit DaemonSet forwards Java app logs to Splunk HEC; Splunk dashboard and saved reports
- **Dynatrace OneAgent** — APM via Operator on K3s; distributed traces for the Java app (getScreenings endpoint, actuator health), node and pod monitoring

### Automation

**Ansible** — six operational playbooks managed from the MacBook Air via Tailscale:
- `health-check.yml` — checks K3s nodes, pods, Oracle, app health endpoint, Splunk
- `rolling-deploy.yml` — triggers ArgoCD sync and waits for rollout
- `rollback.yml` — patches Kustomize overlay tag and redeploys
- `db-validate.yml` — connects to Oracle XE, verifies the screenings table and row count
- `incident-snapshot.yml` — collects pod status, events, logs, node info into a timestamped tarball
- `minio-provision.yml` — idempotent MinIO bucket provisioning (localhost)

**Shell scripts** — five scripts in `scripts/` for day-to-day operations:
- `health-check.sh` — CI-compatible exit code, color-coded output
- `rollback.sh` — patches overlay, commits, pushes, triggers ArgoCD sync
- `log-tail.sh` — streams pod logs with optional grep filter
- `incident-report.sh` — collects diagnostics into a timestamped tarball
- `db-schema-check.sh` — verifies Oracle connectivity and schema integrity

### OpenShift Local (CRC)

The Java screening app deployed to OpenShift 4.21 running on the Mac Mini via CRC. Deployment, Service, and Route manifests in `openshift/`. Verified via `oc` CLI and the OpenShift web console.

## Repository Structure

```
.github/workflows/   GitHub Actions CI pipelines (ci.yaml, ci-java.yml)
app/                 Python/Flask application
java-app/            Spring Boot screening application
java-kustomize/      Kustomize overlays for Java app (base, dev, staging, prod)
k8s/                 Kubernetes manifests
  java-oracle/       Oracle XE StatefulSet, PVC, Service, ConfigMaps
  java-argocd/       ArgoCD AppProject + Application resources
  java-monitoring/   ServiceMonitor for Prometheus scraping
  splunk/            Splunk Deployment, PVC, Service, HEC ConfigMap
  fluentbit/         Fluent Bit DaemonSet, RBAC, ConfigMap
  dynatrace/         Dynatrace OneAgent Operator manifests
helm/                Helm chart for Flask app
kustomize/           Kustomize overlays for Flask app
terraform/           Terraform for K8s namespaces and RBAC
monitoring/          Grafana dashboard JSON, Splunk dashboard XML
ansible/             Ansible playbooks and inventory
openshift/           OpenShift manifests (Deployment, Service, Route)
scripts/             Operational shell scripts
guide/               Lab curriculum and progress logs
```
