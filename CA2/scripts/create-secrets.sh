#!/bin/bash
set -e

read -s -p "Enter MongoDB password: " MONGO_PASS
echo

MONGO_USER="ca2admin"

kubectl create secret generic mongodb-secret \
  -n ca2 \
  --from-literal=MONGO_INITDB_ROOT_USERNAME="$MONGO_USER" \
  --from-literal=MONGO_INITDB_ROOT_PASSWORD="$MONGO_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

ENCODED_USER="$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote_plus(sys.argv[1]))' "$MONGO_USER")"
ENCODED_PASS="$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote_plus(sys.argv[1]))' "$MONGO_PASS")"

kubectl create secret generic processor-secret \
  -n ca2 \
  --from-literal=MONGODB_URI="mongodb://${ENCODED_USER}:${ENCODED_PASS}@mongodb:27017/?authSource=admin" \
  --dry-run=client -o yaml | kubectl apply -f -

unset MONGO_PASS ENCODED_USER ENCODED_PASS

echo "CA2 Kubernetes Secrets created."
