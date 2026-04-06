#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }

NAMESPACE="java-prod"

echo ""
echo "=== Oracle XE Schema Check ==="
echo ""

# Find the Oracle pod
ORACLE_POD=$(kubectl get pod -n "$NAMESPACE" -l app=oracle \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -z "$ORACLE_POD" ]]; then
  fail "Oracle XE pod not found in namespace ${NAMESPACE}"
  exit 1
fi

echo "Oracle pod: ${ORACLE_POD}"
echo ""

# Test basic connectivity
echo "Testing SQL connectivity..."
PING_RESULT=$(kubectl exec -n "$NAMESPACE" "$ORACLE_POD" -- \
  bash -c 'echo "SELECT 1 FROM DUAL;" | sqlplus -S system/$ORACLE_PWD@localhost:1521/XEPDB1' \
  2>/dev/null || echo "ERROR")

if echo "$PING_RESULT" | grep -qE "^\s*1\s*$"; then
  pass "Oracle accepting SQL connections"
else
  fail "SQL connectivity failed. Output: ${PING_RESULT}"
  exit 1
fi

# Check screenings table
echo "Checking screenings table..."
TABLE_CHECK=$(kubectl exec -n "$NAMESPACE" "$ORACLE_POD" -- \
  bash -c 'echo "SELECT COUNT(*) FROM screenings;" | sqlplus -S system/$ORACLE_PWD@localhost:1521/XEPDB1' \
  2>/dev/null || echo "ERROR")

if echo "$TABLE_CHECK" | grep -qE "^[[:space:]]*[0-9]+"; then
  ROWCOUNT=$(echo "$TABLE_CHECK" | grep -E "^[[:space:]]*[0-9]+" | tr -d ' ')
  pass "Table 'screenings' exists with ${ROWCOUNT} rows"
else
  fail "Table 'screenings' not found or query failed. Output: ${TABLE_CHECK}"
  exit 1
fi

# Check column structure
echo "Verifying column structure..."
COL_CHECK=$(kubectl exec -n "$NAMESPACE" "$ORACLE_POD" -- \
  bash -c "echo \"SELECT COLUMN_NAME FROM USER_TAB_COLUMNS WHERE TABLE_NAME='SCREENINGS' ORDER BY COLUMN_ID;\" | sqlplus -S system/\$ORACLE_PWD@localhost:1521/XEPDB1" \
  2>/dev/null || echo "ERROR")

EXPECTED_COLS=("ID" "REFERENCE" "STATUS" "CREATED_AT")
for col in "${EXPECTED_COLS[@]}"; do
  if echo "$COL_CHECK" | grep -q "$col"; then
    pass "Column ${col} present"
  else
    fail "Column ${col} MISSING"
  fi
done
