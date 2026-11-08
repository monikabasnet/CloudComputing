#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"

BACKUP="$ROOT/security/backups/pause-state"
MARKER="$BACKUP/state-saved"

ca3_verify_target

umask 077
mkdir -p "$BACKUP"
chmod 700 "$BACKUP"

if [[ -e "$MARKER" ]]; then
  echo "ERROR: An existing pause state is already saved."
  echo "Refusing to overwrite it."
  exit 1
fi

echo "=== Saving CA3 pause state ==="

kubectl get hpa producer-hpa processor-hpa \
  -n ca2 -o yaml > "$BACKUP/hpa.yaml"

kubectl get deployments,statefulsets -n ca2 \
  -o custom-columns=KIND:.kind,NAME:.metadata.name,REPLICAS:.spec.replicas \
  > "$BACKUP/ca2-replicas.txt"

kubectl get deployments,statefulsets -n monitoring \
  -o custom-columns=KIND:.kind,NAME:.metadata.name,REPLICAS:.spec.replicas \
  > "$BACKUP/monitoring-replicas.txt"

kubectl get prometheus -n monitoring \
  -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas \
  > "$BACKUP/prometheus-replicas.txt"

for file in \
  hpa.yaml \
  ca2-replicas.txt \
  monitoring-replicas.txt \
  prometheus-replicas.txt
do
  test -s "$BACKUP/$file" || {
    echo "ERROR: Missing or empty state file: $file"
    exit 1
  }
done

chmod 600 "$BACKUP"/*

touch "$MARKER"
chmod 600 "$MARKER"

echo "PASS: CA3 pause state saved successfully."
echo "Location: $BACKUP"
