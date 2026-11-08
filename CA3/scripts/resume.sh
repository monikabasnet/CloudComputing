#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
BACKUP="$ROOT/security/backups/pause-state"
ca3_verify_target
[[ -f "$BACKUP/paused" ]] || { echo 'No completed pause marker; refusing to resume automatically'; exit 1; }
[[ -s "$BACKUP/nodegroup-scaling.json" && -s "$BACKUP/hpa.yaml" ]] || exit 1
read -r -p 'Type RESUME-CA3 to proceed: ' confirm
[[ "$confirm" == RESUME-CA3 ]] || exit 1
read -r min max desired < <(python3 - "$BACKUP/nodegroup-scaling.json" <<'PY2'
import json,sys
x=json.load(open(sys.argv[1])); print(x['minSize'],x['maxSize'],x['desiredSize'])
PY2
)
aws eks update-nodegroup-config --cluster-name "$CA3_CLUSTER" --nodegroup-name "$CA3_NODEGROUP" --scaling-config "minSize=$min,maxSize=$max,desiredSize=$desired" --region "$CA3_REGION" --profile "$CA3_PROFILE" >/dev/null
aws eks wait nodegroup-active --cluster-name "$CA3_CLUSTER" --nodegroup-name "$CA3_NODEGROUP" --region "$CA3_REGION" --profile "$CA3_PROFILE"
kubectl wait --for=condition=Ready nodes --all --timeout=600s
kubectl scale statefulset kafka mongodb -n ca2 --replicas=1
kubectl rollout status statefulset/kafka -n ca2 --timeout=600s
kubectl rollout status statefulset/mongodb -n ca2 --timeout=600s
kubectl scale deployment processor producer -n ca2 --replicas=1
kubectl rollout status deployment/processor -n ca2 --timeout=600s
kubectl rollout status deployment/producer -n ca2 --timeout=600s
# HPA yaml from kubectl get contains server metadata; prefer clean manifests.
kubectl apply -f "$ROOT/autoscaling/processor-hpa.yaml" -f "$ROOT/autoscaling/producer-hpa.yaml"
"$ROOT/scripts/verify-rest.sh"
rm "$BACKUP/paused"
echo 'Resume verified. Original monitoring workloads should reconcile with node return; check status.sh.'
