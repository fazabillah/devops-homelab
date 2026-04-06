#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <app-label> [namespace] [filter-pattern]"
  echo "Example: $0 java-screening-app java-prod ERROR"
  echo "Example: $0 java-screening-app java-prod        (no filter, streams all logs)"
  exit 1
fi

APP="$1"
NAMESPACE="${2:-java-prod}"
FILTER="${3:-}"

POD=$(kubectl get pod -n "$NAMESPACE" -l app="$APP" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [[ -z "$POD" ]]; then
  echo "No pod found with label app=${APP} in namespace ${NAMESPACE}"
  exit 1
fi

echo "=== Streaming logs: ${POD} (${NAMESPACE}) ==="
if [[ -z "$FILTER" ]]; then
  echo "    Press Ctrl+C to stop"
  echo ""
  kubectl logs -n "$NAMESPACE" "$POD" -f --tail=50
else
  echo "    Filtering for: ${FILTER}"
  echo "    Press Ctrl+C to stop"
  echo ""
  kubectl logs -n "$NAMESPACE" "$POD" -f --tail=50 | grep --line-buffered "$FILTER"
fi
