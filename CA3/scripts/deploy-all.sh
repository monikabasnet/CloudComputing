#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
ca3_verify_target
for t in kubectl helm; do command -v "$t" >/dev/null || exit 1; done
# Fail closed until fresh-cluster prerequisites are demonstrably satisfied.
for secret in kafka-keystore kafka-client-ca mongodb-server-tls mongodb-secret processor-secret; do
  kubectl get secret "$secret" -n ca2 >/dev/null || { echo "Missing $secret" >&2; exit 2; }
done
for resource in producer-config processor-config; do
  kubectl get configmap "$resource" -n ca2 >/dev/null || exit 2
done
kubectl get storageclass ca2-gp3 >/dev/null || exit 2
kubectl get serviceaccount processor-sa -n ca2 >/dev/null || exit 2
# This deploys only the application layer; it does not claim to install all monitoring.
read -r -p 'Deploy CA3 application workloads to verified cluster? Type DEPLOY-CA3: ' reply
[[ "$reply" == DEPLOY-CA3 ]] || exit 1
kubectl apply -f "$ROOT/security/mongodb-tls-statefulset.yaml"
kubectl rollout status statefulset/mongodb -n ca2 --timeout=600s
kubectl apply -f "$ROOT/security/kafka-tls-only-statefulset.yaml"
kubectl rollout status statefulset/kafka -n ca2 --timeout=600s
kubectl apply -f "$ROOT/processor/deployment.yaml"
kubectl rollout status deployment/processor -n ca2 --timeout=600s
kubectl apply -f "$ROOT/producer/deployment.yaml"
kubectl rollout status deployment/producer -n ca2 --timeout=600s
kubectl apply -f "$ROOT/autoscaling/processor-hpa.yaml"
kubectl apply -f "$ROOT/autoscaling/producer-hpa.yaml"
echo 'Application deployment requested. Run verify-rest.sh and review monitoring separately.'
