#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CA1_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${CA1_DIR}/terraform"
INVENTORY_FILE="${CA1_DIR}/ansible/inventory.ini"

producer_ip="$(terraform -chdir="${TERRAFORM_DIR}" output -raw producer_public_ip)"
kafka_ip="$(terraform -chdir="${TERRAFORM_DIR}" output -raw kafka_public_ip)"
processor_ip="$(terraform -chdir="${TERRAFORM_DIR}" output -raw processor_public_ip)"
mongodb_ip="$(terraform -chdir="${TERRAFORM_DIR}" output -raw mongodb_public_ip)"

# Remove stale SSH host keys left by previous Terraform deployments.
# EC2 public IP addresses may be reassigned after destroy/redeploy.
for host in "${producer_ip}" "${kafka_ip}" "${processor_ip}" "${mongodb_ip}"; do
    ssh-keygen -R "${host}" >/dev/null 2>&1 || true
done

cat > "${INVENTORY_FILE}" <<EOF
[producer]
ca1-producer ansible_host=${producer_ip}

[kafka]
ca1-kafka ansible_host=${kafka_ip}

[processor]
ca1-processor ansible_host=${processor_ip}

[mongodb]
ca1-mongodb ansible_host=${mongodb_ip}

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/ca1-key
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args=-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=~/.ssh/known_hosts
EOF

echo "Generated Ansible inventory: ${INVENTORY_FILE}"