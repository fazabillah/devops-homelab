# DevSecOps Homelab Portfolio

A personal homelab project built on a Mac Mini running two Ubuntu VMs on Parallels Desktop Pro. Demonstrates a production-style DevOps pipeline from infrastructure provisioning to application delivery, observability, and operations — targeting DevOps, platform engineering, and DevSecOps roles.

## Infrastructure

| Component | Details |
|---|---|
| Host | Mac Mini 2018, macOS Sequoia, Parallels Desktop Pro |
| Control plane VM | Ubuntu 24.04.4 LTS (k3s-control), 4 CPU / 8GB RAM — K3s, ArgoCD, Prometheus, Grafana, Loki |
| Worker VM | Ubuntu 24.04.4 LTS (k3s-worker), 4 CPU / 6GB RAM — Oracle XE, Splunk, app workloads |
| Remote access | MacBook Air M4 via Tailscale VPN (stable 100.x.x.x IPs) |
| Kubernetes | K3s (lightweight distribution, single binary) |
| Container registry | Docker Hub (public) |

## Pipeline

```
git push
  ↓
GitHub Actions (path-filtered per service)
  test → docker build (multi-stage)
       → trivy image scan (CVE — fails on CRITICAL/HIGH)
       → trivy config scan (K8s manifest misconfigurations)
       → trivy secret scan (hardcoded credentials)
       → SBOM generation (CycloneDX) uploaded as artifact
       → SARIF results uploaded to GitHub Security tab
  push to Docker Hub
  bot commit: updates kustomize overlay with new image SHA
  ↓
ArgoCD detects manifest change (polls every 3 min)
  ↓
K3s cluster — rolling update
  (containers run non-root, read-only filesystem, no privilege escalation)
  ↓
Prometheus + Grafana (metrics)
Loki + Promtail (logs)
Splunk + Fluent Bit (enterprise log aggregation)
```

## Lab Structure

Four labs built sequentially. Each layer adds to the previous without removing anything.

```
lab0          lab1-java          lab2-platform          lab3-automation
────────      ──────────────    ──────────────    ──────────────
Python/Flask  Java/Spring Boot  Unix operations   Ansible
K3s           React/Nginx       K8s troubleshoot  OpenShift (CRC)
ArgoCD        Oracle XE         Oracle DB ops     Dynatrace APM
GitHub Actions Splunk/Fluent Bit iptables/MetalLB  Shell scripting
Helm/Kustomize Kustomize/ArgoCD Azure AKS         Jenkins CI
Terraform     Prometheus/JVM   Incident response
Trivy         Full-stack demo
Prometheus/
  Grafana/Loki
Blue-green/
  Canary
```

## Role Mapping by Skill Focus

Match your target role's JD requirements to the labs below. Each lab covers a distinct skill domain — complete the labs that align with the skills listed in your JD.

| Skill Focus | Labs | Key Technologies |
|---|---|---|
| Full-stack application engineering (Java + React) | lab0 + lab1-java (all 12 guides) | Java/Spring Boot, React/Vite, Oracle XE, Nginx, Docker, K3s, ArgoCD, GitHub Actions, Prometheus, Splunk |
| Backend application engineering (Java + Oracle) | lab0 + lab1-java guides 01–06 | Java/Spring Boot, Oracle XE, Splunk, Trivy, Kustomize, ArgoCD, Prometheus/JVM metrics |
| Platform operations (Unix, K8s, cloud) | lab0 + lab1-java + lab2-platform | All above + Unix/Linux ops, K8s troubleshooting, Oracle DBA, iptables, MetalLB, Azure AKS |
| Automation and application support | lab0 + lab1-java + lab3-automation | All above + Ansible playbooks, OpenShift, Dynatrace APM, Jenkins, shell scripting |

## Current Progress

See `guide/log-progress.md` for which guides are complete and what comes next.

## Guide Directories

| Directory | Contents |
|---|---|
| `guide/lab0/` | 13 guides — DevOps foundation (Python/Flask pipeline) |
| `guide/lab1-java/` | 12 guides — full-stack application engineering (Java/Oracle/Splunk + React/Nginx) |
| `guide/lab2-platform/` | 7 guides — platform operations (Unix, K8s ops, Oracle DBA, Azure) |
| `guide/lab3-automation/` | 7 guides — automation and application support (Ansible, OpenShift, Dynatrace) |
