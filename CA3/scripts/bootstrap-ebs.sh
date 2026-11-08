#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"

ca3_verify_target

PROFILE="${AWS_PROFILE:-ca2}"
REGION="us-east-2"
CLUSTER="ca3-eks-cluster"
ROLE_NAME="${EBS_ROLE_NAME:-eksctl-ca3-ebs-csi-role}"

echo "=== CA3 EBS CSI Bootstrap ==="

echo "Checking IAM role..."
aws iam get-role \
  --role-name "$ROLE_NAME" \
  --profile "$PROFILE" \
  --query 'Role.RoleName' \
  --output text >/dev/null

echo "PASS: IAM role exists."

echo "Checking EBS CSI add-on..."
status=$(aws eks describe-addon \
  --cluster-name "$CLUSTER" \
  --addon-name aws-ebs-csi-driver \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'addon.status' \
  --output text)

if [[ "$status" != "ACTIVE" ]]; then
  echo "FAIL: EBS CSI add-on is not ACTIVE."
  exit 1
fi

echo "PASS: EBS CSI add-on ACTIVE."

echo "Checking Pod Identity association..."
association=$(aws eks list-pod-identity-associations \
  --cluster-name "$CLUSTER" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'associations[?namespace==`kube-system` && serviceAccount==`ebs-csi-controller-sa`].associationId | [0]' \
  --output text)

if [[ -z "$association" || "$association" == "None" ]]; then
  echo "FAIL: EBS CSI Pod Identity association missing."
  exit 1
fi

actual_role=$(aws eks describe-pod-identity-association \
  --cluster-name "$CLUSTER" \
  --association-id "$association" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'association.roleArn' \
  --output text)

expected_role=$(aws iam get-role \
  --role-name "$ROLE_NAME" \
  --profile "$PROFILE" \
  --query 'Role.Arn' \
  --output text)

if [[ "$actual_role" != "$expected_role" ]]; then
  echo "FAIL: EBS CSI Pod Identity uses an unexpected IAM role."
  exit 1
fi

echo "PASS: Pod Identity association matches IAM role."

echo "Checking StorageClass..."
kubectl get storageclass ca2-gp3 >/dev/null

echo "PASS: ca2-gp3 StorageClass exists."
echo "SUCCESS: EBS CSI prerequisites verified."
