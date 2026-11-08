#!/usr/bin/env bash
set -euo pipefail

PROFILE="${AWS_PROFILE:-ca2}"
REGION="${AWS_REGION:-us-east-2}"
CLUSTER="ca3-eks-cluster"
NODEGROUP="ca3-workers"

echo "=== CA3 AWS Status ==="

aws eks describe-cluster \
  --name "$CLUSTER" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'cluster.{Name:name,Status:status}' \
  --output table

aws eks describe-nodegroup \
  --cluster-name "$CLUSTER" \
  --nodegroup-name "$NODEGROUP" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'nodegroup.{Status:status,Scaling:scalingConfig}' \
  --output json

echo
echo "=== Kubernetes Workloads ==="
kubectl get deployments,statefulsets -n ca2
kubectl get deployments,statefulsets -n monitoring

echo
echo "=== Persistent Volumes ==="
kubectl get pv \
  -o custom-columns=NAME:.metadata.name,VOLUME:.spec.csi.volumeHandle,RECLAIM:.spec.persistentVolumeReclaimPolicy
