#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
command -v eksctl >/dev/null || { echo 'Missing eksctl'; exit 1; }
ca3_verify_target
aws eks describe-cluster --name "$CA3_CLUSTER" --region "$CA3_REGION" --profile "$CA3_PROFILE" >/dev/null
printf '\nCA3 retained volumes (DO NOT delete automatically):\n'
kubectl get pv -o custom-columns=PV:.metadata.name,VOLUME:.spec.csi.volumeHandle,RECLAIM:.spec.persistentVolumeReclaimPolicy
printf '\nCA3 snapshots are NOT deleted. Preserve any needed data and credentials before continuing.\n'
echo 'EKS deletion is irreversible; restoring a fresh cluster will not automatically restore data.'
read -r -p "Type DELETE-${CA3_CLUSTER} to delete this cluster: " answer
[[ "$answer" == "DELETE-${CA3_CLUSTER}" ]] || { echo 'Cancelled'; exit 1; }
eksctl delete cluster --name "$CA3_CLUSTER" --region "$CA3_REGION" --profile "$CA3_PROFILE" --wait
echo 'Cluster deletion requested/completed. Auditing retained AWS resources:'
aws ec2 describe-volumes --region "$CA3_REGION" --profile "$CA3_PROFILE" --query 'Volumes[].{ID:VolumeId,State:State,Size:Size,Tags:Tags}' --output json
aws ec2 describe-snapshots --owner-ids self --region "$CA3_REGION" --profile "$CA3_PROFILE" --query 'Snapshots[].{ID:SnapshotId,Volume:VolumeId,State:State}' --output json
aws elbv2 describe-load-balancers --region "$CA3_REGION" --profile "$CA3_PROFILE" --query 'LoadBalancers[].{Name:LoadBalancerName,ARN:LoadBalancerArn}' --output json
aws ec2 describe-nat-gateways --region "$CA3_REGION" --profile "$CA3_PROFILE" --filter Name=state,Values=available,pending --query 'NatGateways[].{ID:NatGatewayId,VPC:VpcId}' --output json
echo 'Review retained resources, ECR repositories, elastic IPs, and billing. Do not delete resources solely from this account-wide inventory.'
