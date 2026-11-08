#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== Waiting for Kafka consumer backlog to drain ==="

success_count=0

for attempt in $(seq 1 30); do
  if "$ROOT/scripts/check-kafka-lag.sh" >/dev/null 2>&1; then
    success_count=$((success_count + 1))
    echo "Zero-lag verification: $success_count/3"
  else
    success_count=0
    echo "Kafka lag is nonzero or metrics are unavailable."
  fi

  if [[ "$success_count" -ge 3 ]]; then
    echo "PASS: Kafka consumer lag remained zero across three checks."
    exit 0
  fi

  sleep 5
done

echo "FAIL: Kafka consumer lag did not stabilize at zero."
exit 1
