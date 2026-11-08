#!/usr/bin/env bash

CA3_PROFILE="${AWS_PROFILE:-ca2}"
CA3_REGION="us-east-2"
CA3_CLUSTER="ca3-eks-cluster"
CA3_NODEGROUP="ca3-workers"

ca3_verify_target() {
  local account context expected

  account=$(aws sts get-caller-identity \
    --profile "$CA3_PROFILE" \
    --query Account --output text)

  expected="arn:aws:eks:${CA3_REGION}:${account}:cluster/${CA3_CLUSTER}"

  context=$(kubectl config current-context)

  if [[ "$context" != "$expected" ]]; then
    echo "ERROR: Kubernetes context does not match CA3."
    echo "Expected: $expected"
    echo "Actual:   $context"
    return 1
  fi

  echo "PASS: AWS account and Kubernetes context match."
  echo "Cluster: $CA3_CLUSTER"
  echo "Region: $CA3_REGION"
}
