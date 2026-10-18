#!/bin/bash
set -euo pipefail

NAMESPACE="ca2"

echo "=== WORKLOADS AND STORAGE ==="
kubectl get pods,pvc -n "$NAMESPACE"

echo
echo "=== KAFKA TOPICS ==="
kubectl exec -n "$NAMESPACE" kafka-0 -- \
  /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list

echo
echo "=== PRODUCER OUTPUT ==="
kubectl logs -n "$NAMESPACE" deployment/producer \
  -c producer \
  --tail=5

echo
echo "=== PROCESSOR OUTPUT ==="
kubectl logs -n "$NAMESPACE" deployment/processor \
  -c processor \
  --tail=10

echo
echo "=== MONGODB RECORD COUNT ==="
read -s -p "Enter MongoDB password: " MONGO_PASS
echo

kubectl exec -n "$NAMESPACE" mongodb-0 -- mongosh \
  --username ca2admin \
  --password "$MONGO_PASS" \
  --authenticationDatabase admin \
  --quiet \
  --eval 'print("security_events=" + db.getSiblingDB("threat_monitor").security_events.countDocuments({}))'

unset MONGO_PASS

echo
echo "=== REST API TEST ==="
echo "In terminal 1:"
echo "kubectl port-forward -n ca2 service/processor 8080:8080"
echo
echo "In terminal 2:"
echo "curl http://localhost:8080/health"
