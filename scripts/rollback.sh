#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <image-tag>"
  echo "Example: $0 v1.1.0"
  exit 1
fi

TARGET_TAG="$1"
KUSTOMIZE_FILE="java-kustomize/overlays/prod/kustomization.yaml"
NAMESPACE="java-prod"
DEPLOYMENT="java-screening-app"

echo ""
echo "=== Rollback: ${DEPLOYMENT} → ${TARGET_TAG} ==="

# Show what's currently deployed
CURRENT=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "unknown")
warn "Current image: ${CURRENT}"
echo "  Rolling back to tag: ${TARGET_TAG}"
echo ""

# Update the kustomize overlay
if [[ ! -f "$KUSTOMIZE_FILE" ]]; then
  fail "Kustomize file not found: ${KUSTOMIZE_FILE}"
  exit 1
fi

sed -i.bak "s/newTag:.*/newTag: ${TARGET_TAG}/" "$KUSTOMIZE_FILE"
rm -f "${KUSTOMIZE_FILE}.bak"

# Commit and push
git add "$KUSTOMIZE_FILE"
git commit -m "rollback: ${DEPLOYMENT} to ${TARGET_TAG}"
git push origin main

pass "Committed rollback to git"

# Trigger ArgoCD sync
if command -v argocd &>/dev/null; then
  argocd app sync java-app-prod --grpc-web 2>/dev/null && pass "ArgoCD sync triggered" || warn "argocd sync failed — ArgoCD will auto-sync within 3 minutes"
else
  warn "argocd CLI not found — ArgoCD will auto-sync within 3 minutes"
fi

# Wait for rollout
echo ""
echo "Waiting for rollout..."
kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=120s

NEW_IMAGE=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
pass "Rolled back. Running image: ${NEW_IMAGE}"
