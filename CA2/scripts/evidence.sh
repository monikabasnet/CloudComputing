#!/bin/bash
set -euo pipefail

echo "=== ALL KUBERNETES RESOURCES ==="
kubectl get all -A

echo
echo "=== CA2 PERSISTENT STORAGE ==="
kubectl get pvc -n ca2

echo
echo "=== NETWORK POLICIES ==="
kubectl get networkpolicy -n ca2

echo
echo "=== RBAC ==="
kubectl get serviceaccount,role,rolebinding -n ca2

echo
echo "=== HPA ==="
kubectl get hpa -n ca2

echo
echo "=== RESOURCE METRICS ==="
kubectl top pods -n ca2
