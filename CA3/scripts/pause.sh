#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
BACKUP="$ROOT/security/backups/pause-state"
ca3_verify_target
for f in state-saved hpa.yaml ca2-replicas.txt monitoring-replicas.txt prometheus-replicas.txt nodegroup-scaling.json; do
 [[ -e "$BACKUP/$f" ]] || { echo "Missing $f"; exit 1; }
done
# Preserve initial state. No automatic recapture or overwrite.
[[ ! -e "$BACKUP/paused" ]] || { echo 'Already marked paused'; exit 1; }
echo 'CAUTION: not yet live-tested; may interrupt applications and monitoring.'
read -r -p 'Type PAUSE-CA3 to proceed: ' confirm
[[ "$confirm" == PAUSE-CA3 ]] || exit 1
# Stop producer before testing drain, keeping HPA from recreating it.
kubectl delete hpa producer-hpa -n ca2 --ignore-not-found
kubectl scale deployment producer -n ca2 --replicas=0
kubectl wait --for=delete pod -l app=producer -n ca2 --timeout=180s
# Requires independently maintained exporter port-forward at localhost:9308.
# Fail closed if metrics are unavailable.
"$ROOT/scripts/wait-kafka-drain.sh"
kubectl delete hpa processor-hpa -n ca2 --ignore-not-found
kubectl scale deployment processor -n ca2 --replicas=0
kubectl wait --for=delete pod -l app=processor -n ca2 --timeout=180s
kubectl scale statefulset kafka mongodb -n ca2 --replicas=0
kubectl wait --for=delete pod/kafka-0 -n ca2 --timeout=300s
kubectl wait --for=delete pod/mongodb-0 -n ca2 --timeout=300s
# Monitoring components are intentionally left configured. Nodes at zero
# stop pods; on resume they return with the nodes. Prometheus Operator and
# Helm-managed resources must not be manually fought by scaling.
aws eks update-nodegroup-config --cluster-name "$CA3_CLUSTER" --nodegroup-name "$CA3_NODEGROUP" --scaling-config minSize=0,maxSize=3,desiredSize=0 --region "$CA3_REGION" --profile "$CA3_PROFILE" >/dev/null
aws eks wait nodegroup-active --cluster-name "$CA3_CLUSTER" --nodegroup-name "$CA3_NODEGROUP" --region "$CA3_REGION" --profile "$CA3_PROFILE"
touch "$BACKUP/paused"
echo 'Pause update completed; verify EC2 instances terminated. EKS control plane and EBS still bill.'
