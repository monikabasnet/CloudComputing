#!/bin/bash
set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-ca2}"
CLUSTER="ca2-eks-cluster"
REGION="us-east-2"

echo "Installing EKS Pod Identity Agent..."

if ! AWS_PROFILE="$AWS_PROFILE" eksctl get addon \
  --cluster "$CLUSTER" \
  --region "$REGION" \
  --name eks-pod-identity-agent >/dev/null 2>&1; then

  AWS_PROFILE="$AWS_PROFILE" eksctl create addon \
    --cluster "$CLUSTER" \
    --region "$REGION" \
    --name eks-pod-identity-agent
fi

echo "Installing AWS EBS CSI driver..."

if ! AWS_PROFILE="$AWS_PROFILE" eksctl get addon \
  --cluster "$CLUSTER" \
  --region "$REGION" \
  --name aws-ebs-csi-driver >/dev/null 2>&1; then

  AWS_PROFILE="$AWS_PROFILE" eksctl create addon \
    --cluster "$CLUSTER" \
    --region "$REGION" \
    --name aws-ebs-csi-driver
fi

echo "Enabling VPC CNI NetworkPolicy support..."

aws eks update-addon \
  --cluster-name "$CLUSTER" \
  --addon-name vpc-cni \
  --configuration-values '{"enableNetworkPolicy":"true"}' \
  --region "$REGION" \
  --profile "$AWS_PROFILE"

echo "Cluster platform setup complete."
