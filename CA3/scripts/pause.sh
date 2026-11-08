#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
BACKUP="$ROOT/security/backups/pause-state"
ca3_verify_target
for file in state-saved hpa.yaml ca2-replicas.txt monitoring-replicas.txt prometheus-replicas.txt nodegroup-scaling.json; do
  [[ -e "$BACKUP/$file" ]] || { echo "Missing recovery file: $file" >&2; exit 1; }
done
[[ ! -e "$BACKUP/paused" && ! -e "$BACKUP/pause-in-progress" ]] || { echo 'Already paused or interrupted; investigate manually.' >&2; exit 1; }
python3 - "$BACKUP/nodegroup-scaling.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]))
assert all(isinstance(x[k],int) for k in ('minSize','maxSize','desiredSize'))
assert 0 <= x['minSize'] <= x['desiredSize'] <= x['maxSize']
PY
# Require all workloads to be at their captured starting replica counts.
while read -r kind name replicas; do
  [[ "$kind" == KIND ]] && continue
  case "$kind" in Deployment|StatefulSet) ;; *) echo "Unexpected resource kind: $kind" >&2; exit 1;; esac
  actual=$(kubectl get "${kind,,}" "$name" -n ca2 -o jsonpath='{.spec.replicas}')
  [[ "$actual" == "$replicas" ]] || { echo "Replica drift: $name saved=$replicas actual=$actual" >&2; exit 1; }
done < "$BACKUP/ca2-replicas.txt"
echo 'WARNING: stops CA3 application and requests zero EKS worker nodes; EKS control-plane, EBS, and snapshots can continue billing.'
read -r -p 'Type PAUSE-CA3 to continue: ' confirmation
[[ "$confirmation" == PAUSE-CA3 ]] || exit 1
touch "$BACKUP/pause-in-progress"
# The producer must be stopped before consumer lag is assessed.
kubectl delete hpa producer-hpa -n ca2 --ignore-not-found
kubectl scale deployment/producer -n ca2 --replicas=0
kubectl wait --for=delete pod -l app=producer -n ca2 --timeout=180s
# Start our own exporter port-forward. Do not depend on a user's existing session.
log=$(mktemp)
kubectl port-forward -n monitoring service/kafka-exporter-prometheus-kafka-exporter 19308:9308 >"$log" 2>&1 &
pf=$!
cleanup() { kill "$pf" 2>/dev/null || true; wait "$pf" 2>/dev/null || true; rm -f "$log"; }
trap cleanup EXIT
ready=0
for i in $(seq 1 20); do
  if curl -fsS --max-time 2 http://127.0.0.1:19308/metrics >/dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
[[ "$ready" == 1 ]] || { echo 'Kafka exporter port-forward unavailable' >&2; exit 1; }
METRICS_URL=http://127.0.0.1:19308/metrics "$ROOT/scripts/wait-kafka-drain.sh"
cleanup
trap - EXIT
kubectl delete hpa processor-hpa -n ca2 --ignore-not-found
kubectl scale deployment/processor -n ca2 --replicas=0
kubectl wait --for=delete pod -l app=processor -n ca2 --timeout=180s
kubectl scale statefulset/kafka statefulset/mongodb -n ca2 --replicas=0
kubectl wait --for=delete pod/kafka-0 -n ca2 --timeout=300s
kubectl wait --for=delete pod/mongodb-0 -n ca2 --timeout=300s
aws eks update-nodegroup-config --cluster-name "$CA3_CLUSTER" --nodegroup-name "$CA3_NODEGROUP" --scaling-config minSize=0,maxSize=3,desiredSize=0 --region "$CA3_REGION" --profile "$CA3_PROFILE" >/dev/null
aws eks wait nodegroup-active --cluster-name "$CA3_CLUSTER" --nodegroup-name "$CA3_NODEGROUP" --region "$CA3_REGION" --profile "$CA3_PROFILE"
# The EKS node group can report ACTIVE while instances are still terminating.
actual=$(aws eks describe-nodegroup --cluster-name "$CA3_CLUSTER" --nodegroup-name "$CA3_NODEGROUP" --region "$CA3_REGION" --profile "$CA3_PROFILE" --query 'nodegroup.scalingConfig.desiredSize' --output text)
[[ "$actual" == 0 ]] || { echo 'Nodegroup desired capacity is not zero' >&2; exit 1; }
mv "$BACKUP/pause-in-progress" "$BACKUP/paused"
echo 'Pause requested and nodegroup configuration verified. Inspect EC2 termination and remaining charges.'
