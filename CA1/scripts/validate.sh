#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CA1_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${CA1_DIR}/terraform"
ANSIBLE_DIR="${CA1_DIR}/ansible"

PROCESSOR_IP="$(terraform -chdir="${TERRAFORM_DIR}" output -raw processor_public_ip)"

echo "=== CA1 Pipeline Validation ==="

echo
echo "[1/4] Checking Ansible connectivity..."
cd "${ANSIBLE_DIR}"
ansible all -m ping --ask-vault-pass

echo
echo "[2/4] Checking Processor REST API health..."
curl --fail --silent --show-error \
    "http://${PROCESSOR_IP}:8080/health"
echo

echo
echo "[3/4] Publishing authentication event..."
ansible-playbook site.yml \
    --ask-vault-pass \
    -e "run_producer=true"

echo
echo "[4/4] Retrieving processed events..."
curl --fail --silent --show-error \
    "http://${PROCESSOR_IP}:8080/events"
echo

echo
echo "=== CA1 pipeline validation completed successfully ==="