#!/bin/bash
set -euo pipefail

NAMESPACE="ca2"
DEPLOYMENT="producer"
WINDOW=30

read -s -p "Enter MongoDB password: " MONGO_PASS
echo

count_events() {
  kubectl exec -n "$NAMESPACE" mongodb-0 -- mongosh \
    --username ca2admin \
    --password "$MONGO_PASS" \
    --authenticationDatabase admin \
    --quiet \
    --eval 'db.getSiblingDB("threat_monitor").security_events.countDocuments({})'
}

measure() {
  local replicas="$1"

  echo "Scaling Producer to ${replicas} replica(s)..."

  kubectl scale deployment "$DEPLOYMENT" \
    -n "$NAMESPACE" \
    --replicas="$replicas"

  kubectl rollout status deployment "$DEPLOYMENT" \
    -n "$NAMESPACE"

  sleep 15

  local start
  local end
  local events
  local rate

  start="$(count_events)"
  sleep "$WINDOW"
  end="$(count_events)"

  events=$((end-start))
  rate="$(awk -v e="$events" -v w="$WINDOW" \
    'BEGIN { printf "%.2f", e/w }')"

  echo "${replicas},${events},${rate}"
}

echo "replicas,events_30s,events_per_sec"

measure 1
measure 3

unset MONGO_PASS
