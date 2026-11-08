#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

source "$ROOT/scripts/common.sh"
ca3_verify_target

echo "=== CA3 RBAC Bootstrap ==="

kubectl create namespace ca2 \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$ROOT/security/processor-rbac.yaml"

echo "Verifying processor ServiceAccount..."

kubectl get serviceaccount processor-sa -n ca2

echo "Verifying least-privilege permissions..."

IDENTITY="system:serviceaccount:ca2:processor-sa"

if kubectl auth can-i get configmaps \
  --as="$IDENTITY" -n ca2 --quiet; then
  echo "PASS: ConfigMap read permitted."
else
  echo "FAIL: ConfigMap read permission missing."
  exit 1
fi

if kubectl auth can-i delete secrets \
  --as="$IDENTITY" -n ca2 --quiet; then
  echo "FAIL: Processor unexpectedly allowed to delete Secrets."
  exit 1
else
  echo "Checking whether denial is expected..."

  result=$(kubectl auth can-i delete secrets \
    --as="$IDENTITY" -n ca2 2>&1) || status=$?

  if [[ "$result" == "no" && "${status:-1}" -eq 1 ]]; then
    echo "PASS: Secret deletion denied."
  else
    echo "FAIL: RBAC verification returned an unexpected result."
    echo "Check whether your identity has impersonation permissions."
    exit 1
  fi
fi

echo "SUCCESS: CA3 least-privilege RBAC verified."
