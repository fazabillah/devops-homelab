#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
SNAPSHOT_DIR="/tmp/java-incident-${TIMESTAMP}"
OUTPUT_FILE="${HOME}/Desktop/java-incident-${TIMESTAMP}.tar.gz"
NAMESPACES=("java-dev" "java-staging" "java-prod" "monitoring")

mkdir -p "$SNAPSHOT_DIR"

echo ""
echo "=== Incident Report: ${TIMESTAMP} ==="
echo ""

# Pod status across all namespaces
echo "Collecting pod status..."
for ns in "${NAMESPACES[@]}"; do
  {
    echo "=== Namespace: ${ns} ==="
    kubectl get pods -n "$ns" -o wide 2>/dev/null || echo "(namespace not found)"
    echo ""
  } >> "${SNAPSHOT_DIR}/pods.txt"
done
pass "Pod status collected"

# Events (last 1 hour)
echo "Collecting events..."
for ns in "${NAMESPACES[@]}"; do
  {
    echo "=== Events: ${ns} ==="
    kubectl get events -n "$ns" --sort-by='.lastTimestamp' 2>/dev/null | tail -50 || echo "(none)"
    echo ""
  } >> "${SNAPSHOT_DIR}/events.txt"
done
pass "Events collected"

# Pod logs from prod (last 500 lines each)
echo "Collecting pod logs from java-prod..."
mkdir -p "${SNAPSHOT_DIR}/logs"
for pod in $(kubectl get pods -n java-prod -o name 2>/dev/null); do
  name=$(basename "$pod")
  kubectl logs -n java-prod "$name" --tail=500 > "${SNAPSHOT_DIR}/logs/${name}.txt" 2>&1 || true
done
pass "Pod logs collected"

# Pod descriptions
echo "Collecting pod descriptions..."
kubectl describe pods -n java-prod > "${SNAPSHOT_DIR}/pod-descriptions.txt" 2>/dev/null || true
pass "Pod descriptions collected"

# Node status and resource usage
echo "Collecting node info..."
{
  echo "=== Nodes ==="
  kubectl get nodes -o wide
  echo ""
  echo "=== Resource Usage ==="
  kubectl top nodes 2>/dev/null || echo "(metrics-server not available)"
  echo ""
  echo "=== Pod Resource Usage (java-prod) ==="
  kubectl top pods -n java-prod 2>/dev/null || echo "(metrics-server not available)"
} > "${SNAPSHOT_DIR}/node-info.txt"
pass "Node info collected"

# ArgoCD app status
echo "Collecting ArgoCD status..."
{
  argocd app list 2>/dev/null || echo "(argocd CLI not available)"
} > "${SNAPSHOT_DIR}/argocd-status.txt"
pass "ArgoCD status collected"

# Create tarball
tar -czf "$OUTPUT_FILE" -C /tmp "java-incident-${TIMESTAMP}"
rm -rf "$SNAPSHOT_DIR"

echo ""
pass "Incident report saved to: ${OUTPUT_FILE}"
echo "      Share this file with the on-call team or attach to the incident ticket."
