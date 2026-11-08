#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"

ca3_verify_target

echo "=== CA3 Services and ConfigMaps Bootstrap ==="

kubectl create namespace ca2 \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create namespace monitoring \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Creating application ConfigMaps..."

kubectl create configmap producer-config \
  -n ca2 \
  --from-literal=KAFKA_BROKER=kafka-0.kafka.ca2.svc.cluster.local:9094 \
  --from-literal=KAFKA_TOPIC=auth-events \
  --from-literal=PRODUCE_INTERVAL=1 \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create configmap processor-config \
  -n ca2 \
  --from-literal=API_PORT=8080 \
  --from-literal=KAFKA_BROKER=kafka-0.kafka.ca2.svc.cluster.local:9094 \
  --from-literal=KAFKA_TOPIC=auth-events \
  --from-literal=MONGODB_DATABASE=threat_monitor \
  --from-literal=MONGODB_COLLECTION=security_events \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Creating Kubernetes Services..."

cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: kafka
  namespace: ca2
spec:
  clusterIP: None
  selector:
    app: kafka
  ports:
    - name: controller
      port: 9093
      targetPort: 9093
    - name: kafka-tls
      port: 9094
      targetPort: 9094
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  namespace: ca2
spec:
  clusterIP: None
  selector:
    app: mongodb
  ports:
    - name: mongodb
      port: 27017
      targetPort: 27017
---
apiVersion: v1
kind: Service
metadata:
  name: processor
  namespace: ca2
spec:
  selector:
    app: processor
  ports:
    - name: http
      port: 8080
      targetPort: 8080
YAML

kubectl apply -f \
  "$ROOT/observability/producer-metrics-service.yaml"

echo "PASS: CA3 Services and ConfigMaps bootstrap completed."
