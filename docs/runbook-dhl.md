# DHL Stack Runbook

Operational reference for the DHL lab stack: Spring Boot screening app, Oracle XE, Splunk, ArgoCD on K3s.

Three scenarios are covered. Each follows the same structure: what you observe first, how you dig in, and how you fix it.

---

## Scenario 1: Oracle DB Unreachable

**Symptoms**

- API returns `{"status":"degraded","reason":"database unavailable","data":[]}` instead of screening data
- Grafana: `hikaricp_connections_timeout_total` counter is increasing
- Splunk search returns WARN entries: `database unavailable` from `ScreeningController`

```
index=main sourcetype=_json
| search kubernetes.namespace_name=dhl-prod
| search log="*database unavailable*"
| table _time, kubernetes.pod_name, log
| sort -_time
```

**Diagnosis**

```bash
# Step 1: Check if the Oracle pod is running
kubectl get pods -n dhl-prod
# If oracle-0 is not Running/Ready, that is the problem

# Step 2: Check Oracle logs for startup or error messages
kubectl logs oracle-0 -n dhl-prod --tail=50
# Look for: DATABASE IS READY TO USE! (it hasn't finished init)
# Look for: ORA-XXXXX (Oracle error codes)

# Step 3: Check if the PVC is bound
kubectl get pvc -n dhl-prod
# If oracle-data-pvc shows Pending, storage provisioning failed

# Step 4: Check if the DB secret has the right password
kubectl get secret oracle-db-secret -n dhl-prod \
  -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
echo
# Verify this matches what Oracle was initialized with

# Step 5: If Oracle is Running, test the connection directly
kubectl exec -it oracle-0 -n dhl-prod -- \
  sqlplus system/YourStrongPassword123@XEPDB1
# If this fails: password mismatch or Oracle not fully initialized
```

**Fix**

| Root cause | Fix |
|---|---|
| Oracle pod not started / initializing | Wait — first boot takes 3–5 min. Watch: `kubectl logs -f oracle-0 -n dhl-prod` |
| Oracle pod CrashLoopBackOff | `kubectl describe pod oracle-0 -n dhl-prod` — check events section for cause |
| PVC stuck Pending | `kubectl describe pvc oracle-data-pvc -n dhl-prod` — local-path provisioner issue |
| Wrong DB_PASSWORD in secret | Recreate: `kubectl create secret generic oracle-db-secret --from-literal=DB_PASSWORD=CorrectPassword -n dhl-prod --dry-run=client -o yaml \| kubectl apply -f -` then restart app pods |
| App pods have stale secret env | `kubectl rollout restart deployment/prod-dhl-screening-app -n dhl-prod` |

---

## Scenario 2: App Pod OOMKilled

**Symptoms**

- `kubectl get pods -n dhl-prod` shows the app pod restarting (RESTARTS count climbing)
- Pod describe shows `OOMKilled` as the last state reason
- Grafana: `jvm_memory_used_bytes{area="heap"}` was pinned at or near `jvm_memory_max_bytes`

**Diagnosis**

```bash
# Step 1: Confirm OOMKilled
kubectl describe pod -n dhl-prod -l app=dhl-screening-app
# Look for:
#   Last State: Terminated
#   Reason: OOMKilled

# Step 2: Check recent events for the namespace
kubectl get events -n dhl-prod --sort-by='.lastTimestamp' | tail -20
# Look for: OOMKilling events from kubelet

# Step 3: Check current memory limit vs request
kubectl get deployment prod-dhl-screening-app -n dhl-prod \
  -o jsonpath='{.spec.template.spec.containers[0].resources}'
# Current limits: memory 256Mi, requests 128Mi

# Step 4: In Grafana — check jvm_memory_used_bytes trend before the restart
# Panel: JVM Heap Usage
# If heap was steadily climbing to max before the OOMKill: heap leak or undersized limit
# If heap was normal but OOMKill happened: non-heap memory (metaspace, native) was the cause
```

**Fix**

Increase the memory limit in the Kustomize overlay. ArgoCD will detect the change and redeploy without manual intervention.

Edit `dhl-kustomize/overlays/prod/patch-replicas.yaml` (or add a new memory patch file):

```yaml
# dhl-kustomize/overlays/prod/patch-memory.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dhl-screening-app
spec:
  template:
    spec:
      containers:
        - name: dhl-screening-app
          resources:
            requests:
              memory: "256Mi"
            limits:
              memory: "512Mi"
```

Add it to `dhl-kustomize/overlays/prod/kustomization.yaml` under `patches:`, then commit and push. ArgoCD deploys within 3 minutes.

If the OOMKill recurs and heap was not the cause (non-heap memory), add a JVM flag to cap metaspace:

```yaml
# In the base deployment env block:
- name: JAVA_TOOL_OPTIONS
  value: "-Xmx200m -XX:MaxMetaspaceSize=128m"
```

---

## Scenario 3: ArgoCD Sync Stuck or OutOfSync

**Symptoms**

- CI pipeline completed successfully (image pushed, manifest bot-commit landed)
- `argocd app get dhl-app-prod` shows `OutOfSync` or new pods have not rolled out
- ArgoCD UI shows a sync error or a hook failure

**Diagnosis**

```bash
# Step 1: Force a refresh (ArgoCD polls every 3 min — this skips the wait)
argocd app get dhl-app-prod --refresh

# Step 2: Check what ArgoCD thinks is out of sync
argocd app diff dhl-app-prod

# Step 3: Confirm the bot commit actually landed in the overlay
cat dhl-kustomize/overlays/prod/kustomization.yaml | grep newTag
# Should show the SHA from the latest CI run, not 'placeholder'

# Step 4: Check if a sync operation is already in progress or stuck
argocd app get dhl-app-prod
# Look for: Operation State — Running (longer than 5 min = stuck)

# Step 5: Check ArgoCD application controller logs for errors
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=50
```

**Fix**

| Root cause | Fix |
|---|---|
| ArgoCD poll hasn't fired yet | `argocd app sync dhl-app-prod` — triggers immediate sync |
| Bot commit did not push (CI error) | Check GitHub Actions run → `Update image tag in Kustomize overlay` step. Fix and re-push. |
| Sync operation stuck/hung | `argocd app terminate-op dhl-app-prod` then `argocd app sync dhl-app-prod` |
| Hook error blocking sync | `argocd app get dhl-app-prod` → look for failed PreSync/PostSync hook → `argocd app delete-resource dhl-app-prod --kind Job --name <hook-name>` then re-sync |
| Self-heal is fighting a manual change | ArgoCD's `selfHeal: true` will revert manual `kubectl apply` changes. Either sync through Git or temporarily disable selfHeal to investigate. |

---

## Quick Reference Commands

```bash
# Namespace health overview
kubectl get pods -n dhl-prod
kubectl get pods -n monitoring | grep -E 'splunk|fluent'

# App readiness
kubectl rollout status deployment/prod-dhl-screening-app -n dhl-prod

# Live logs from app
kubectl logs -f -n dhl-prod -l app=dhl-screening-app

# Oracle status
kubectl exec -it oracle-0 -n dhl-prod -- sqlplus system/YourStrongPassword123@XEPDB1

# ArgoCD all-app status
argocd app list

# Port-forwards for local access
kubectl port-forward svc/prod-dhl-screening-app 8080:8080 -n dhl-prod &
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring &
kubectl port-forward svc/splunk 8000:8000 -n monitoring &
```
