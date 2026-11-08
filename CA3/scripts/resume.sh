#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
BACKUP="$ROOT/security/backups/pause-state"
ca3_verify_target
[[ -f "$BACKUP/paused" ]] || { echo 'No completed pause marker. If pause failed, investigate partial state manually.' >&2; exit 1; }
for file in ca2-replicas.txt nodegroup-scaling.json hpa.yaml; do [[ -s "$BACKUP/$file" ]] || exit 1; done
read -r -p 'Type RESUME-CA3 to continue: ' confirmation
[[ "$confirmation" == RESUME-CA3 ]] || exit 1
read -r min max desired < <(python3 - "$BACKUP/nodegroup-scaling.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); print(x['minSize'],x['maxSize'],x['desiredSize'])
PY
)
aws eks update-nodegroup-config --cluster-name "$CA3_CLUSTER" --nodegroup-name "$CA3_NODEGROUP" --scaling-config "minSize=$min,maxSize=$max,desiredSize=$desired" --region "$CA3_REGION" --profile "$CA3_PROFILE" >/dev/null
aws eks wait nodegroup-active --cluster-name "$CA3_CLUSTER" --nodegroup-name "$CA3_NODEGROUP" --region "$CA3_REGION" --profile "$CA3_PROFILE"
# Wait for the originally requested number of Ready nodes, not just one.
for i in $(seq 1 60); do
  ready=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2 == "Ready" {n++} END {print n+0}')
  if [[ "$ready" -ge "$desired" ]]; then break; fi
  sleep 10
done
[[ "$ready" -ge "$desired" ]] || { echo "Only $ready of $desired nodes Ready" >&2; exit 1; }
# Restore StatefulSets first, then Deployments, based on saved desired replicas.
for kind in StatefulSet Deployment; do
  while read -r saved_kind name replicas; do
    [[ "$saved_kind" == "$kind" ]] || continue
    kubectl scale "${kind,,}/$name" -n ca2 --replicas="$replicas"
    if [[ "$replicas" -gt 0 ]]; then kubectl rollout status "${kind,,}/$name" -n ca2 --timeout=600s; fi
  done < "$BACKUP/ca2-replicas.txt"
done
kubectl apply -f "$ROOT/autoscaling/processor-hpa.yaml" -f "$ROOT/autoscaling/producer-hpa.yaml"
"$ROOT/scripts/verify-rest.sh"
rm "$BACKUP/paused"
echo 'Application resumed and REST verified. Verify monitoring workloads, Kafka lag, and AWS billing separately.'
