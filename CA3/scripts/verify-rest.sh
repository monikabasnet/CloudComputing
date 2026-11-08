#!/usr/bin/env bash
set -euo pipefail

PORT=18080
BASE_URL="http://127.0.0.1:${PORT}"
LOG_FILE="$(mktemp)"

cleanup() {
  if [[ -n "${PF_PID:-}" ]]; then
    kill "$PF_PID" 2>/dev/null || true
    wait "$PF_PID" 2>/dev/null || true
  fi
  rm -f "$LOG_FILE"
}
trap cleanup EXIT

echo "=== CA3 Automated REST Verification ==="

kubectl port-forward -n ca2 \
  service/processor "${PORT}:8080" \
  >"$LOG_FILE" 2>&1 &

PF_PID=$!

echo "Waiting for processor REST service..."

ready=false
for i in $(seq 1 30); do
  if curl -fsS --max-time 2 \
    "${BASE_URL}/health" >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 1
done

if [[ "$ready" != true ]]; then
  echo "FAIL: Processor REST service unavailable"
  cat "$LOG_FILE"
  exit 1
fi

BASE_URL="$BASE_URL" python3 - <<'PY'
import json
import os
import urllib.request

base = os.environ["BASE_URL"]

def request(path):
    with urllib.request.urlopen(base + path, timeout=10) as response:
        assert response.status == 200, f"{path}: HTTP {response.status}"
        return response.read()

health = json.loads(request("/health"))
assert health["status"] == "ok"
assert health["mongodb"] == "connected"
assert health["kafka_topic"] == "auth-events"
print("PASS: /health returns healthy MongoDB and Kafka topic status")

events = json.loads(request("/events"))
assert isinstance(events, list)
print(f"PASS: /events returns a JSON array ({len(events)} events)")

alerts = json.loads(request("/alerts"))
assert isinstance(alerts, list)
print(f"PASS: /alerts returns a JSON array ({len(alerts)} alerts)")

metrics = request("/metrics").decode()
assert "http_requests_total" in metrics
assert "http_request_duration_seconds" in metrics
assert "mongodb_inserts_total" in metrics
print("PASS: /metrics exposes REST and MongoDB metrics")

print("SUCCESS: All four CA3 REST endpoint checks passed")
PY
