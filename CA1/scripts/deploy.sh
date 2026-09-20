#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"

echo "=== CA1 Automated Deployment ==="

echo "[1/4] Initializing Terraform..."
terraform -chdir="${TERRAFORM_DIR}" init

echo "[2/4] Applying AWS infrastructure..."
terraform -chdir="${TERRAFORM_DIR}" apply

echo "[3/4] Generating Ansible inventory..."
"${PROJECT_ROOT}/scripts/generate-inventory.sh"

echo "[4/4] Configuring services with Ansible..."
cd "${ANSIBLE_DIR}"
ansible-playbook site.yml --ask-vault-pass

echo
echo "=== CA1 deployment completed successfully ==="

terraform -chdir="${TERRAFORM_DIR}" output