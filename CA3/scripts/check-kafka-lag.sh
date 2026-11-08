#!/usr/bin/env bash
set -euo pipefail

METRICS_URL="${METRICS_URL:-http://localhost:9308/metrics}"

echo "=== CA3 Kafka Consumer Lag Check ==="

metrics=$(curl -fsS --max-time 10 "$METRICS_URL") || {
  echo "FAIL: Kafka Exporter metrics unavailable."
  echo "Start the Kafka Exporter port-forward first."
  exit 1
}

lag=$(printf '%s\n' "$metrics" | awk '
  /^kafka_consumergroup_lag_sum\{/ &&
  /consumergroup="ca0-threat-processor"/ &&
  /topic="auth-events"/ {
    sum += $NF
    found = 1
  }
  END {
    if (!found) exit 1
    printf "%.0f", sum
  }
') || {
  echo "FAIL: Consumer lag metric not found."
  exit 1
}

echo "Consumer lag: $lag"

if [[ "$lag" != "0" ]]; then
  echo "FAIL: Consumer lag is not zero."
  exit 1
fi

echo "PASS: Kafka consumer lag is zero."
