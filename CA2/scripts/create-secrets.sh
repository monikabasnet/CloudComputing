#!/bin/bash
set -euo pipefail

read -s -p "Enter MongoDB password: " MONGO_PASSWORD
echo

MONGO_USER="ca2admin"

ENCODED_USER="$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote_plus(sys.argv[1]))' "$MONGO_USER")"
ENCODED_PASS="$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote_plus(sys.argv[1]))' "$MONGO_PASSWORD")"

MONGODB_URI="mongodb://${ENCODED_USER}:${ENCODED_PASS}@mongodb:27017/?authSource=admin"

export MONGO_PASSWORD
export MONGODB_URI

envsubst < mongodb/secret.template.yaml | kubectl apply -f -
envsubst < processor/secret.template.yaml | kubectl apply -f -

unset MONGO_PASSWORD MONGODB_URI ENCODED_USER ENCODED_PASS

echo "CA2 Kubernetes Secrets applied from declarative templates."
