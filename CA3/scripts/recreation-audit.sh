#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
missing=0
check() { if [[ -f "$ROOT/$1" ]]; then printf 'PRESENT %s\n' "$1"; else printf 'MISSING %s\n' "$1"; missing=$((missing+1)); fi; }
echo 'CA3 reproducibility audit (read-only)'
for f in eks/cluster.yaml autoscaling/producer-hpa.yaml autoscaling/processor-hpa.yaml producer/deployment.yaml processor/deployment.yaml security/kafka-tls-only-statefulset.yaml security/mongodb-tls-statefulset.yaml observability/prometheus-values.yaml observability/loki-values.yaml observability/alloy-values.yaml; do check "$f"; done
for f in scripts/bootstrap-ebs.sh scripts/bootstrap-tls-secrets.sh scripts/bootstrap-rbac.sh scripts/bootstrap-services-configmaps.sh scripts/build-push-images.sh scripts/deploy-all.sh; do check "$f"; done
if (( missing )); then echo "BLOCKED: $missing prerequisite files absent. Do not tear down expecting one-command recreation."; exit 2; fi
echo 'File presence complete; still requires fresh-cluster integration testing.'
