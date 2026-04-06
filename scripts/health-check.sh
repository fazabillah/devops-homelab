#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

APP_PROD="java-prod"
APP_NAME="java-screening-app"
APP_PORT="8080"
FAILED=0

echo ""
echo "=== Stack Health Check: $(date '+%Y-%m-%d %H:%M:%S') ==="
echo ""

# 1. K3s nodes
echo "--- Nodes ---"
NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready" | wc -l | tr -d ' ' || true)
if [[ "$NOT_READY" -eq 0 ]]; then
  TOTAL=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
  pass "All ${TOTAL} node(s) Ready"
else
  fail "${NOT_READY} node(s) not Ready"
  kubectl get nodes --no-headers | grep -v " Ready"
  FAILED=$((FAILED + 1))
fi

echo ""

# 2. App prod pods
echo "--- App Pods (${APP_PROD}) ---"
PROBLEM_PODS=$(kubectl get pods -n "$APP_PROD" --no-headers 2>/dev/null | grep -vE "Running|Completed" | wc -l | tr -d ' ' || true)
TOTAL_PODS=$(kubectl get pods -n "$APP_PROD" --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [[ "$TOTAL_PODS" -eq 0 ]]; then
  warn "No pods found in ${APP_PROD}"
elif [[ "$PROBLEM_PODS" -eq 0 ]]; then
  pass "${TOTAL_PODS} pod(s) Running in ${APP_PROD}"
else
  fail "${PROBLEM_PODS} pod(s) not Running in ${APP_PROD}"
  kubectl get pods -n "$APP_PROD" --no-headers | grep -vE "Running|Completed"
  FAILED=$((FAILED + 1))
fi

echo ""

# 3. Oracle XE
echo "--- Oracle XE ---"
ORACLE_STATUS=$(kubectl get pods -n "$APP_PROD" -l app=oracle --no-headers 2>/dev/null | awk '{print $3}' || echo "NotFound")
if [[ "$ORACLE_STATUS" == "Running" ]]; then
  pass "Oracle XE Running"
elif [[ -z "$ORACLE_STATUS" ]]; then
  warn "Oracle XE pod not found"
else
  fail "Oracle XE status: ${ORACLE_STATUS}"
  FAILED=$((FAILED + 1))
fi

echo ""

# 4. Screening app health endpoint
echo "--- App Health Endpoint ---"
APP_POD=$(kubectl get pod -n "$APP_PROD" -l app="$APP_NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -z "$APP_POD" ]]; then
  warn "No ${APP_NAME} pod found in ${APP_PROD}"
else
  HEALTH=$(kubectl exec -n "$APP_PROD" "$APP_POD" -- \
    wget -qO- "http://localhost:${APP_PORT}/actuator/health" 2>/dev/null || echo "ERROR")
  if echo "$HEALTH" | grep -q '"status":"UP"'; then
    pass "/actuator/health → UP"
  else
    fail "/actuator/health returned: ${HEALTH}"
    FAILED=$((FAILED + 1))
  fi
fi

echo ""

# 5. Splunk HEC
echo "--- Splunk HEC ---"
SPLUNK_POD=$(kubectl get pod -n monitoring -l app=splunk --no-headers -o name 2>/dev/null | head -1 || echo "")
if [[ -z "$SPLUNK_POD" ]]; then
  warn "Splunk pod not found in monitoring namespace"
else
  SPLUNK_STATUS=$(kubectl get pods -n monitoring -l app=splunk --no-headers 2>/dev/null | awk '{print $3}')
  if [[ "$SPLUNK_STATUS" == "Running" ]]; then
    pass "Splunk Running"
  else
    fail "Splunk status: ${SPLUNK_STATUS}"
    FAILED=$((FAILED + 1))
  fi
fi

echo ""
echo "=== Result ==="
if [[ "$FAILED" -eq 0 ]]; then
  pass "All checks passed"
  exit 0
else
  fail "${FAILED} check(s) failed"
  exit 1
fi