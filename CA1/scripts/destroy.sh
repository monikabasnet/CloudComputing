#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CA1_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${CA1_DIR}/terraform"

echo "=== CA1 Automated Teardown ==="
echo
echo "The following Terraform-managed AWS resources will be destroyed:"
echo

terraform -chdir="${TERRAFORM_DIR}" plan -destroy

echo
read -r -p "Continue with destruction? [y/N] " response

if [[ ! "${response}" =~ ^[Yy]$ ]]; then
    echo "Destroy cancelled."
    exit 0
fi

terraform -chdir="${TERRAFORM_DIR}" destroy -auto-approve

echo
echo "=== CA1 teardown completed successfully ==="